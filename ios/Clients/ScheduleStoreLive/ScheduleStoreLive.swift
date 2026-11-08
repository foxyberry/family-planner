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
            delete: { id in try database.run { try $0.delete(id) } }
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
            try insert("routine:\(routine.kid):\(routine.dayType.rawValue):\(routine.from.year)-\(routine.from.month)-\(routine.from.day)", group: "routine", order: index, routine)
        }
        for item in SeedData.items(today: today, calendar: calendar) {
            try insert("item:\(item.id)", group: "item", order: 0, item)
        }
        try insert("meta:seeded", group: "meta", order: 0, SeedData.version)
        try context.save()
    }

    func snapshot() throws -> ScheduleSnapshot {
        ScheduleSnapshot(kids: try values("kid"), routines: try values("routine"), items: try values("item"))
    }

    func put(_ items: [ScheduleItem]) throws {
        for item in items {
            for old in try fetch("item").filter({ $0.key == "item:\(item.id)" }) { context.delete(old) }
            try insert("item:\(item.id)", group: "item", order: 0, item)
        }
        try context.save()
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
