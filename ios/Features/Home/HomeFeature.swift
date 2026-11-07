import ComposableArchitecture
import Domain
import Foundation
import HolidayProvider
import ScheduleStore

/// The kids' home screen: each kid's slots for today and the time now (boards A1, E1, E3).
@Reducer
public struct HomeFeature {
    public enum Layout: Equatable, Sendable {
        /// A1: Kid A's clock, Kid A's next slots and Kid B's now/next pictures.
        case twoKids
        /// E1: one child, with the "Next" list.
        case oneKid
        /// E3: a weekend or holiday for Kid A.
        case dayOff
    }

    public struct KidDay: Equatable, Sendable {
        public var kid: Kid
        public var dayKind: DayKind
        public var slots: [Slot]
    }

    @ObservableState
    public struct State: Equatable {
        public var today: Day?
        public var minute = 0
        /// One entry per kid, in the order the store keeps them. Empty when nothing could be loaded.
        public var days: [KidDay] = []

        public init() {}

        public var layout: Layout {
            if days.first?.dayKind == .dayOff { return .dayOff }
            return days.count == 1 ? .oneKid : .twoKids
        }
    }

    public enum Action: Equatable {
        case task
        case tick(Date)
        case reload
        case loaded(ScheduleSnapshot?, holidays: [Holiday])
        /// The clock was held for 2 seconds; the app opens the grown-up lock.
        case clockHoldCompleted
    }

    @Dependency(\.calendar) var calendar
    @Dependency(\.date) var date
    @Dependency(\.scheduleStore) var scheduleStore
    @Dependency(\.holidays) var holidays

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let now = date.now
                state.today = Day(now, calendar: calendar)
                state.minute = minute(of: now)
                return .send(.reload)

            case let .tick(now):
                let day = Day(now, calendar: calendar)
                state.minute = minute(of: now)
                // Before the first load `.task` sets the day; only a real day change reloads.
                guard let today = state.today, day != today else { return .none }
                state.today = day
                return .send(.reload)

            case .reload:
                guard let year = state.today?.year else { return .none }
                return .run { [scheduleStore, holidays] send in
                    let snapshot = try? await scheduleStore.load()
                    await send(.loaded(snapshot, holidays: await holidays.holidays(year)))
                }

            case let .loaded(snapshot, holidays):
                guard let snapshot, let today = state.today else {
                    state.days = []
                    return .none
                }
                let holidayDays = Set(holidays.map(\.day))
                state.days = snapshot.kids.map { kid in
                    KidDay(kid: kid,
                           dayKind: DayPlanner.dayKind(on: today, kid: kid, holidays: holidayDays, calendar: calendar),
                           slots: DayPlanner.slots(on: today, kid: kid, routines: snapshot.routines,
                                                   items: snapshot.items, holidays: holidayDays, calendar: calendar))
                }
                return .none

            case .clockHoldCompleted:
                return .none
            }
        }
    }

    private func minute(of date: Date) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
