import ComposableArchitecture
import Domain
import Foundation

/// Everything the screens read about the family's days.
public struct ScheduleSnapshot: Equatable, Sendable {
    public var kids: [Kid]
    public var routines: [Routine]
    public var items: [ScheduleItem]
    /// Every kid's morning missions (spec "MVP data"), in no particular order; sort by `order`.
    public var missions: [Mission]

    public init(kids: [Kid], routines: [Routine], items: [ScheduleItem], missions: [Mission] = []) {
        self.kids = kids
        self.routines = routines
        self.items = items
        self.missions = missions
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
    /// Saves a day template (C6). It is used from its `from` day; an older one stays for the days
    /// before. Saving again for the same kid, day type and day replaces it.
    public var saveRoutine: @Sendable (_ routine: Routine) async throws -> Void
    /// Replaces one kid's missions with `missions` (C5: add, rename, reorder, remove).
    public var saveMissions: @Sendable (_ kid: Kid.ID, _ missions: [Mission]) async throws -> Void
    /// A kid's marks for a date; an empty day when there are none yet.
    public var missionDay: @Sendable (_ kid: Kid.ID, _ date: Day) async throws -> MissionDay
    /// Saves a kid's marks for a date and drops days older than `MissionDay.kept` before it.
    public var saveMissionDay: @Sendable (_ day: MissionDay) async throws -> Void
}

extension ScheduleStore: TestDependencyKey {
    public static let testValue = Self()

    /// Seed data in memory, for previews. Seeded on the first load around the preview's `\.date` and
    /// `\.calendar`, so a preview can pin the day like a test does.
    public static var previewValue: Self {
        let items = LockIsolated<[ScheduleItem]?>(nil)
        let routines = LockIsolated(SeedData.routines)
        let missions = LockIsolated(SeedData.missions)
        let days = LockIsolated<[MissionDay]>([])
        @Sendable func seeded() -> [ScheduleItem] {
            @Dependency(\.date.now) var now
            @Dependency(\.calendar) var calendar
            return items.withValue { list in
                if list == nil { list = SeedData.items(today: Day(now, calendar: calendar), calendar: calendar) }
                return list ?? []
            }
        }
        return Self(
            load: { ScheduleSnapshot(kids: SeedData.kids, routines: routines.value, items: seeded(),
                                     missions: missions.value) },
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
            },
            saveRoutine: { routine in
                routines.withValue { list in
                    list.removeAll { $0.kid == routine.kid && $0.dayType == routine.dayType && $0.from == routine.from }
                    list.append(routine)
                }
            },
            saveMissions: { kid, new in
                missions.withValue { list in
                    list.removeAll { $0.kid == kid }
                    list += new
                }
            },
            missionDay: { kid, date in
                days.value.first { $0.kid == kid && $0.date == date } ?? MissionDay(kid: kid, date: date)
            },
            saveMissionDay: { day in
                days.withValue { list in
                    list.removeAll { $0.kid == day.kid && $0.date == day.date }
                    list.append(day)
                }
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
