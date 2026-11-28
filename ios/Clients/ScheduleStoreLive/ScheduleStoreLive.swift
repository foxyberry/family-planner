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

    /// The SwiftData store on this device. It starts empty: first-run setup (S1–S4) writes the family
    /// with `replaceFamily` (user, 2026-11-09). A store an older build seeded is kept as it is.
    public static func live(directory: URL) -> ScheduleStore {
        let database = Database(url: directory.appendingPathComponent(liveFileName))
        return ScheduleStore(
            load: { try database.run { try $0.snapshot() } },
            save: { item in try database.run { try $0.put([item]) } },
            saveAll: { items in try database.run { try $0.put(items) } },
            delete: { id in try database.run { try $0.delete(id) } },
            saveRoutine: { routine in try database.run { try $0.put(routine) } },
            saveMissions: { kid, missions in try database.run { try $0.put(missions, of: kid) } },
            saveBundle: { bundle in try database.run { try $0.put(bundle) } },
            deleteBundle: { id in try database.run { try $0.deleteBundle(id) } },
            windowMissions: { kid, date, window in
                try database.run { try $0.windowMissions(kid: kid, date: date, window: window) }
            },
            saveWindowMissions: { marks in
                @Dependency(\.calendar) var calendar
                try database.run { try $0.put(marks, calendar: calendar) }
            },
            slides: { kid, date in try database.run { try $0.slides(kid: kid, date: date) } },
            saveSlide: { slide in
                @Dependency(\.calendar) var calendar
                try database.run { try $0.put(slide, calendar: calendar) }
            },
            saveBusPlan: { plan in try database.run { try $0.put(plan) } },
            saveKid: { kid in try database.run { try $0.put(kid) } },
            replaceFamily: { family in try database.run { try $0.replace(with: family) } }
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
                let opened = try ModelContainer(for: StoredRecord.self, configurations: ModelConfiguration(url: url))
                // Per-day mission marks from before mission windows (2026-11-09) were development data
                // only: they are dropped, not moved (user decision).
                try Records(context: ModelContext(opened)).dropOldMissionDays()
                // Issue 024: missions are kept in bundles; a store from before keeps its missions as each
                // kid's Morning routine.
                try Records(context: ModelContext(opened)).moveMissionsIntoBundles()
                // Kept only once both moves are done: a move that throws is tried again on the next call,
                // never skipped for the rest of the process (#285 review).
                container = opened
            }
            return try body(Records(context: ModelContext(container!)))
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

    /// Everything replaced by `family`, saved once.
    func replace(with family: ScheduleSnapshot) throws {
        for record in try context.fetch(FetchDescriptor<StoredRecord>()) { context.delete(record) }
        for (index, kid) in family.kids.enumerated() {
            try insert("kid:\(kid.id)", group: "kid", order: index, kid)
        }
        for (index, routine) in family.routines.enumerated() {
            try insert(Self.key(routine), group: "routine", order: index, routine)
        }
        for item in family.items {
            try insert("item:\(item.id)", group: "item", order: 0, item)
        }
        for (index, bundle) in family.bundles.enumerated() {
            try insert(Self.bundleKey(bundle.id), group: "bundle", order: index, bundle)
        }
        for plan in family.busPlans {
            try insert(Self.planKey(plan), group: "busPlan", order: 0, plan)
        }
        try context.save()
    }

    func snapshot() throws -> ScheduleSnapshot {
        ScheduleSnapshot(kids: try values("kid"), routines: try values("routine"), items: try values("item"),
                         bundles: try values("bundle"), busPlans: try values("busPlan"))
    }

    /// Replaces the kid's record in place (keeping its order); a new kid (G6f "Add a child") goes
    /// after the others.
    func put(_ kid: Kid) throws {
        let kids = try fetch("kid")
        if let old = kids.first(where: { $0.key == "kid:\(kid.id)" }) {
            old.payload = try encoder.encode(kid)
        } else {
            try insert("kid:\(kid.id)", group: "kid", order: (kids.map(\.order).max() ?? -1) + 1, kid)
        }
        try context.save()
    }

    /// Saves one route per kid and event. A School route stored before routes were per event (key
    /// "busPlan:{kid}") is replaced by it.
    func put(_ plan: BusPlan) throws {
        let key = Self.planKey(plan)
        let legacy = plan.event == .school ? "busPlan:\(plan.kid)" : key
        for old in try fetch("busPlan") where old.key == key || old.key == legacy { context.delete(old) }
        try insert(key, group: "busPlan", order: 0, plan)
        try context.save()
    }

    static func planKey(_ plan: BusPlan) -> String { "busPlan:\(plan.kid):\(eventKey(plan.event))" }

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

    /// The kid's Morning routine takes `missions` (kept in place, or added after the other bundles).
    func put(_ missions: [Mission], of kid: Kid.ID) throws {
        let key = Self.bundleKey(MissionBundle.morningID(for: kid))
        let existing = try fetch("bundle")
        let old = existing.first { $0.key == key }
        var bundle = old.flatMap { try? decoder.decode(MissionBundle.self, from: $0.payload) }
            ?? MissionBundle.morning(kid: kid, missions: [])
        bundle.missions = missions.sorted { $0.order < $1.order }
        let order = old?.order ?? existing.count
        if let old { context.delete(old) }
        try insert(key, group: "bundle", order: order, bundle)
        try context.save()
    }

    /// Saves `bundle` in its place, or after the other bundles when it is new (C5).
    func put(_ bundle: MissionBundle) throws {
        let key = Self.bundleKey(bundle.id)
        let existing = try fetch("bundle")
        let old = existing.first { $0.key == key }
        let order = old?.order ?? existing.count
        if let old { context.delete(old) }
        try insert(key, group: "bundle", order: order, bundle)
        try context.save()
    }

    /// Removes a bundle (C5); an event that picks it skips the missing id.
    func deleteBundle(_ id: MissionBundle.ID) throws {
        for record in try fetch("bundle") where record.key == Self.bundleKey(id) { context.delete(record) }
        try context.save()
    }

    /// Missions stored one by one (before issue 024) become each kid's Morning routine, once; a kid
    /// that already has one keeps it.
    func moveMissionsIntoBundles() throws {
        let old = try fetch("mission")
        guard !old.isEmpty else { return }
        let missions = old.compactMap { try? decoder.decode(Mission.self, from: $0.payload) }
        let existing = try fetch("bundle")
        for (index, bundle) in MissionBundle.mornings(from: missions).enumerated()
        where !existing.contains(where: { $0.key == Self.bundleKey(bundle.id) }) {
            try insert(Self.bundleKey(bundle.id), group: "bundle", order: existing.count + index, bundle)
        }
        // The design's answer (2026-11-23): each such kid's Morning routine goes on School's before list
        // and the first outing of their weekend templates, so the mornings work as before.
        let kidsWithMissions = Set(missions.map(\.kid))
        let routineRecords = try fetch("routine")
        for record in try fetch("kid") {
            guard let kid = try? decoder.decode(Kid.self, from: record.payload), kidsWithMissions.contains(kid.id) else { continue }
            let theirs = routineRecords.compactMap { record in
                (try? decoder.decode(Routine.self, from: record.payload)).map { (record, $0) }
            }.filter { $0.1.kid == kid.id }
            let attached = MissionBundle.attachingMorning(to: kid, routines: theirs.map(\.1))
            record.payload = try encoder.encode(attached.kid)
            for ((routineRecord, before), after) in zip(theirs, attached.routines) where before != after {
                routineRecord.payload = try encoder.encode(after)
            }
        }
        for record in old { context.delete(record) }
        try context.save()
    }

    static func bundleKey(_ id: UUID) -> String { "bundle:\(id)" }

    func windowMissions(kid: Kid.ID, date: Day, window: MissionWindow) throws -> WindowMissions {
        let key = Self.windowKey(kid: kid, date: date, window: window)
        guard let record = try fetch("window").first(where: { $0.key == key }) else {
            return WindowMissions(kid: kid, date: date, window: window)
        }
        return try decoder.decode(WindowMissions.self, from: record.payload)
    }

    func slides(kid: Kid.ID, date: Day) throws -> [OutingSlide] {
        let prefix = "slide:\(kid):\(Self.dateKey(date)):"
        return try fetch("slide").filter { $0.key.hasPrefix(prefix) }
            .compactMap { try? decoder.decode(OutingSlide.self, from: $0.payload) }
    }

    /// Saves a window's marks and drops windows older than `MissionDay.kept` days before it.
    func put(_ marks: WindowMissions, calendar: Calendar) throws {
        let key = Self.windowKey(kid: marks.kid, date: marks.date, window: marks.window)
        try prune("window", replacing: key, oldest: marks.date.adding(days: -MissionDay.kept, calendar: calendar),
                  date: { try? decoder.decode(WindowMissions.self, from: $0).date })
        try insert(key, group: "window", order: 0, marks)
        try context.save()
    }

    /// Saves a slide and drops slides older than `MissionDay.kept` days before it.
    func put(_ slide: OutingSlide, calendar: Calendar) throws {
        let key = Self.slideKey(slide)
        try prune("slide", replacing: key, oldest: slide.date.adding(days: -MissionDay.kept, calendar: calendar),
                  date: { try? decoder.decode(OutingSlide.self, from: $0).date })
        try insert(key, group: "slide", order: 0, slide)
        try context.save()
    }

    func dropOldMissionDays() throws {
        let old = try fetch("missionDay")
        guard !old.isEmpty else { return }
        for record in old { context.delete(record) }
        try context.save()
    }

    /// Deletes the record with `key` and every record of `group` dated before `oldest`.
    private func prune(_ group: String, replacing key: String, oldest: Day, date: (Data) -> Day?) throws {
        // A record that no longer decodes (an "after" window from before 2026-11-14) is dropped too.
        for record in try fetch(group) where record.key == key || (date(record.payload).map { $0 < oldest } ?? true) {
            context.delete(record)
        }
    }

    static func dateKey(_ date: Day) -> String { "\(date.year)-\(date.month)-\(date.day)" }

    static func windowKey(kid: Kid.ID, date: Day, window: MissionWindow) -> String {
        "window:\(kid):\(dateKey(date)):\(eventKey(window))"
    }

    static func slideKey(_ slide: OutingSlide) -> String {
        "slide:\(slide.kid):\(dateKey(slide.date)):\(slide.outing.map(eventKey) ?? "morning")"
    }

    private static func eventKey(_ window: MissionWindow) -> String {
        switch window {
        case .morning: "morning"
        case let .before(event): "before-" + eventKey(event)
        case .evening: "evening"
        case let .blockBefore(kind, title, start):
            "before-block-\(kind.rawValue)-\(title)" + (start.map { "-\($0)" } ?? "")
        }
    }

    static func eventKey(_ event: EventRef) -> String {
        switch event {
        case .school: "school"
        case let .item(id): "item-\(id)"
        }
    }

    static func key(_ routine: Routine) -> String {
        // A day's own template has its own key, so it never replaces the day type's template.
        "routine:\(routine.kid):\(routine.dayType.rawValue):\(dateKey(routine.from))" + (routine.onlyOn == nil ? "" : ":only")
    }

    func delete(_ id: ScheduleItem.ID) throws {
        for old in try fetch("item").filter({ $0.key == "item:\(id)" }) { context.delete(old) }
        try context.save()
    }

    private func fetch(_ group: String) throws -> [StoredRecord] {
        try context.fetch(FetchDescriptor<StoredRecord>(predicate: #Predicate { $0.group == group },
                                                        sortBy: [SortDescriptor(\.order)]))
    }

    /// A record an older build wrote in another shape (the first seed's routines) is skipped, not an
    /// error, so the rest of the family still loads.
    private func values<T: Decodable>(_ group: String) throws -> [T] {
        try fetch(group).compactMap { try? decoder.decode(T.self, from: $0.payload) }
    }

    private func insert(_ key: String, group: String, order: Int, _ value: some Encodable) throws {
        context.insert(StoredRecord(key: key, group: group, order: order, payload: try encoder.encode(value)))
    }
}
