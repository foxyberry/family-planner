import ComposableArchitecture
import Domain
import Foundation

/// Everything the screens read about the family's days.
public struct ScheduleSnapshot: Equatable, Sendable {
    public var kids: [Kid]
    public var routines: [Routine]
    public var items: [ScheduleItem]

    public init(kids: [Kid], routines: [Routine], items: [ScheduleItem]) {
        self.kids = kids
        self.routines = routines
        self.items = items
    }
}

/// Where kids, routines and schedule items are kept. Features depend on this interface only;
/// the app target injects the on-device store (`ScheduleStoreLive`).
@DependencyClient
public struct ScheduleStore: Sendable {
    public var load: @Sendable () async throws -> ScheduleSnapshot
    /// Adds the item, or replaces the one with the same id.
    public var save: @Sendable (_ item: ScheduleItem) async throws -> Void
    /// Saves several items in one write (an every-week item split into old and new series).
    public var saveAll: @Sendable (_ items: [ScheduleItem]) async throws -> Void
    public var delete: @Sendable (_ id: ScheduleItem.ID) async throws -> Void
}

extension ScheduleStore: TestDependencyKey {
    public static let testValue = Self()

    /// Seed data in memory, for previews. Seeded on the first load around the preview's `\.date` and
    /// `\.calendar`, so a preview can pin the day like a test does.
    public static var previewValue: Self {
        let items = LockIsolated<[ScheduleItem]?>(nil)
        @Sendable func seeded() -> [ScheduleItem] {
            @Dependency(\.date.now) var now
            @Dependency(\.calendar) var calendar
            return items.withValue { list in
                if list == nil { list = SeedData.items(today: Day(now, calendar: calendar), calendar: calendar) }
                return list ?? []
            }
        }
        return Self(
            load: { ScheduleSnapshot(kids: SeedData.kids, routines: SeedData.routines, items: seeded()) },
            save: { item in
                _ = seeded()
                items.withValue { $0?.removeAll { $0.id == item.id }; $0?.append(item) }
            },
            saveAll: { new in
                _ = seeded()
                items.withValue { list in
                    list?.removeAll { old in new.contains { $0.id == old.id } }
                    list? += new
                }
            },
            delete: { id in
                _ = seeded()
                items.withValue { $0?.removeAll { $0.id == id } }
            }
        )
    }

}

extension DependencyValues {
    public var scheduleStore: ScheduleStore {
        get { self[ScheduleStore.self] }
        set { self[ScheduleStore.self] = newValue }
    }
}
