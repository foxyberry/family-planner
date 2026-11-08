import ComposableArchitecture
import Domain
import Foundation
import ScheduleStore
import SwiftData
import Synchronization

/// One stored value. The Domain value is kept as JSON in `payload`: SwiftData does not store enums
/// with associated values (`Recurrence`, `Audience`) reliably, and these records are tiny.
@Model
final class StoredRecord {
    @Attribute(.unique) var key: String
    var group: String
    var order: Int
    var payload: Data

    init(key: String, group: String, order: Int, payload: Data) {
        self.key = key
        self.group = group
        self.order = order
        self.payload = payload
    }
}

extension ScheduleStore {
    /// The store file inside the folder passed to `live(directory:)`.
    public static let liveFileName = "schedule.store"

    /// The SwiftData store on this device. The first load seeds the fake family (`SeedData`) around
    /// today, read from the app's `\.date` and `\.calendar` at the time of the call, so it follows the
    /// app's clock and time zone (and the developer time machine), never the device's.
    public static func live(directory: URL) -> ScheduleStore {
        let database = Database(url: directory.appendingPathComponent(liveFileName))
        return ScheduleStore(
            load: { try database.run { try $0.snapshot() } },
            save: { item in try database.run { try $0.put([item]) } },
            saveAll: { items in try database.run { try $0.put(items) } },
            delete: { id in try database.run { try $0.delete(id) } },
            saveRoutine: { routine in try database.run { try $0.put(routine) } },
            saveMissions: { kid, missions in try database.run { try $0.put(missions, of: kid) } },
            missionDay: { kid, date in try database.run { try $0.missionDay(kid: kid, date: date) } },
            saveMissionDay: { day in
                @Dependency(\.calendar) var calendar
                try database.run { try $0.put(day, calendar: calendar) }
            },
            saveBusPlan: { plan in try database.run { try $0.put(plan) } }
        )
    }
}

/// Opens the container once and runs every call on a fresh context, one call at a time.
private final class Database: Sendable {
    private let url: URL
    private let container = Mutex<ModelContainer?>(nil)

    init(url: URL) {
        self.url = url
    }

    func run<T>(_ body: (Records) throws -> T) throws -> T {
        try container.withLock { container in
            if container == nil {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true)
                container = try ModelContainer(for: StoredRecord.self, configurations: ModelConfiguration(url: url))
            }
            let records = Records(context: ModelContext(container!))
            @Dependency(\.date.now) var now
            @Dependency(\.calendar) var calendar
            try records.seedIfNeeded(today: Day(now, calendar: calendar), calendar: calendar)
            return try body(records)
        }
    }
}

private struct Records {
    let context: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(context: ModelContext) {
        self.context = context
    }

    /// Seeds an empty store. A store written by an older seed (a lower or missing `meta:seeded`
    /// version, or routines in an old shape) is cleared and seeded again: the data is fake until M4.
    func seedIfNeeded(today: Day, calendar: Calendar) throws {
        let meta = try fetch("meta")
        if !meta.isEmpty {
            let version = meta.first { $0.key == "meta:seeded" }.flatMap { try? decoder.decode(Int.self, from: $0.payload) }
            let routinesDecode = (try? values("routine") as [Routine]) != nil
            if let version, version >= SeedData.version, routinesDecode { return }
        }
        for record in try context.fetch(FetchDescriptor<StoredRecord>()) { context.delete(record) }
        for (index, kid) in SeedData.kids.enumerated() {
            try insert("kid:\(kid.id)", group: "kid", order: index, kid)
        }
        for (index, routine) in SeedData.routines.enumerated() {
            try insert(Self.key(routine), group: "routine", order: index, routine)
        }
        for item in SeedData.items(today: today, calendar: calendar) {
            try insert("item:\(item.id)", group: "item", order: 0, item)
        }
        for mission in SeedData.missions {
            try insert("mission:\(mission.id)", group: "mission", order: mission.order, mission)
        }
        try insert("meta:seeded", group: "meta", order: 0, SeedData.version)
        try context.save()
    }

    func snapshot() throws -> ScheduleSnapshot {
        ScheduleSnapshot(kids: try values("kid"), routines: try values("routine"), items: try values("item"),
                         missions: try values("mission"), busPlans: try values("busPlan"))
    }

    func put(_ plan: BusPlan) throws {
        for old in try fetch("busPlan").filter({ $0.key == "busPlan:\(plan.kid)" }) { context.delete(old) }
        try insert("busPlan:\(plan.kid)", group: "busPlan", order: 0, plan)
        try context.save()
    }

    func put(_ items: [ScheduleItem]) throws {
        for item in items {
            for old in try fetch("item").filter({ $0.key == "item:\(item.id)" }) { context.delete(old) }
            try insert("item:\(item.id)", group: "item", order: 0, item)
        }
        try context.save()
    }

    func put(_ routine: Routine) throws {
        let key = Self.key(routine)
        let existing = try fetch("routine")
        for old in existing where old.key == key { context.delete(old) }
        try insert(key, group: "routine", order: existing.count, routine)
        try context.save()
    }

    func put(_ missions: [Mission], of kid: Kid.ID) throws {
        for old in try fetch("mission") {
            if let mission = try? decoder.decode(Mission.self, from: old.payload), mission.kid == kid {
                context.delete(old)
            }
        }
        for mission in missions {
            try insert("mission:\(mission.id)", group: "mission", order: mission.order, mission)
        }
        try context.save()
    }

    func missionDay(kid: Kid.ID, date: Day) throws -> MissionDay {
        let key = Self.dayKey(kid: kid, date: date)
        guard let record = try fetch("missionDay").first(where: { $0.key == key }) else {
            return MissionDay(kid: kid, date: date)
        }
        return try decoder.decode(MissionDay.self, from: record.payload)
    }

    /// Saves the day and drops days older than `MissionDay.kept` before it.
    func put(_ day: MissionDay, calendar: Calendar) throws {
        let oldest = day.date.adding(days: -MissionDay.kept, calendar: calendar)
        for record in try fetch("missionDay") {
            guard let stored = try? decoder.decode(MissionDay.self, from: record.payload) else { continue }
            if record.key == Self.dayKey(kid: day.kid, date: day.date) || stored.date < oldest {
                context.delete(record)
            }
        }
        try insert(Self.dayKey(kid: day.kid, date: day.date), group: "missionDay", order: 0, day)
        try context.save()
    }

    static func dayKey(kid: Kid.ID, date: Day) -> String {
        "missionDay:\(kid):\(date.year)-\(date.month)-\(date.day)"
    }

    static func key(_ routine: Routine) -> String {
        "routine:\(routine.kid):\(routine.dayType.rawValue):\(routine.from.year)-\(routine.from.month)-\(routine.from.day)"
    }

    func delete(_ id: ScheduleItem.ID) throws {
        for old in try fetch("item").filter({ $0.key == "item:\(id)" }) { context.delete(old) }
        try context.save()
    }

    private func fetch(_ group: String) throws -> [StoredRecord] {
        try context.fetch(FetchDescriptor<StoredRecord>(predicate: #Predicate { $0.group == group },
                                                        sortBy: [SortDescriptor(\.order)]))
    }

    private func values<T: Decodable>(_ group: String) throws -> [T] {
        try fetch(group).map { try decoder.decode(T.self, from: $0.payload) }
    }

    private func insert(_ key: String, group: String, order: Int, _ value: some Encodable) throws {
        context.insert(StoredRecord(key: key, group: group, order: order, payload: try encoder.encode(value)))
    }
}
