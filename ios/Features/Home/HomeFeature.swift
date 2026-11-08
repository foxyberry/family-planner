import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import HolidayProvider
import ScheduleStore
import Strings

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
        public var dayType: DayType
        public var slots: [Slot]
        /// From the template's evening routine to wake-up (board A1n); `nil` keeps the day look.
        public var night: NightSpan? = nil
    }

    @ObservableState
    public struct State: Equatable {
        public var today: Day?
        /// Today's weekday in the app's calendar (set with `today`).
        public var weekday: Weekday?
        public var minute = 0
        /// One entry per kid, in the order the store keeps them. Empty when nothing could be loaded.
        public var days: [KidDay] = []

        public init() {}

        /// "Saturday" (E3), from the app's calendar, never the device's.
        public var dayName: String? { weekday.map(DayText.name) }

        /// The sky switch's choice (board 0g): it lasts until the next planned change of look.
        public var skyOverride: KidLook?
        /// True for the 1.2 s of the switch animation; taps meanwhile are ignored.
        public var isSkyAnimating = false
        /// Seconds since the last touch, counted in the root's 1-second ticks (never from the date).
        public var idleSeconds = 0
        /// Board 0g2 idle wink: one more each time 20 s pass without a touch.
        public var winks = 0
        /// Spec "Picture rigs": a play id per drawn slot start; a slot plays when its id goes up.
        public var plays: [Int: Int] = [:]
        /// True for the 1.2 s of a play; taps meanwhile are ignored.
        public var isPlaying = false

        /// Board A1n: the kid screens follow the clock kid's (the first kid's) evening and wake-up.
        public var plannedLook: KidLook {
            days.first?.night?.contains(minute) == true ? .night : .day
        }

        /// What the kid screens show: the sky switch's choice, else the plan.
        public var look: KidLook { skyOverride ?? plannedLook }

        /// Board 0g2 new slot: the current slot's start; when it changes, its picture hops.
        public var currentSlotStart: Int? {
            DayPlanner.now(at: minute, in: days.first?.slots ?? []).current?.start
        }

        /// Board 0g2 on the hour: the hand's disc pulses when this changes.
        public var hour: Int { minute / 60 }

        /// Board E3 (2026-11-08): a school holiday on a weekday, the only holiday line on kid screens.
        public var isSchoolHoliday: Bool {
            guard let weekday, weekday != .saturday, weekday != .sunday else { return false }
            return days.first?.dayType == .sunday
        }

        /// The right panel's first line (spec "Hub text"): the weekday, or "Monday · Holiday" on a
        /// weekday school holiday.
        public var dayHeading: String? {
            guard let dayName else { return nil }
            return isSchoolHoliday ? L10n.tr("home.day.holiday", dayName) : dayName
        }

        /// The switch's VoiceOver label: "Day. Tap for night." / "Night. Tap for day.".
        public var skySwitchLabel: String { look == .day ? L10n.tr("home.sky.day") : L10n.tr("home.sky.night") }

        public var layout: Layout {
            if let type = days.first?.dayType, type != .weekday { return .dayOff }
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
        /// The kid tapped the day/night switch (board 0g).
        case skySwitchTapped
        case skyAnimationEnded
        /// Any touch on the kid screen; it restarts the idle count.
        case touched
        /// The kid tapped the drawn slot that starts at this minute.
        case slotTapped(Int)
        case playEnded
    }

    @Dependency(\.calendar) var calendar
    @Dependency(\.date) var date
    @Dependency(\.continuousClock) var clock
    @Dependency(\.scheduleStore) var scheduleStore
    @Dependency(\.holidays) var holidays

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let now = date.now
                let day = Day(now, calendar: calendar)
                state.today = day
                state.weekday = day.weekday(calendar)
                state.minute = minute(of: now)
                return .send(.reload)

            case let .tick(now):
                state.idleSeconds += 1
                if state.idleSeconds >= 20 {
                    state.idleSeconds = 0
                    state.winks += 1
                }
                let day = Day(now, calendar: calendar)
                let planned = state.plannedLook
                state.minute = minute(of: now)
                // The next planned change (evening routine, wake-up) clears the switch's choice.
                if state.plannedLook != planned { state.skyOverride = nil }
                // Before the first load `.task` sets the day; only a real day change reloads.
                guard let today = state.today, day != today else { return .none }
                state.today = day
                state.weekday = day.weekday(calendar)
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
                           dayType: DayPlanner.dayType(on: today, holidays: holidayDays, calendar: calendar),
                           slots: DayPlanner.slots(on: today, kid: kid, routines: snapshot.routines,
                                                   items: snapshot.items, holidays: holidayDays, calendar: calendar),
                           night: DayPlanner.nightSpan(of: DayPlanner.template(
                               for: kid.id, on: today, routines: snapshot.routines, holidays: holidayDays,
                               calendar: calendar)))
                }
                return .none

            case .clockHoldCompleted:
                return .none

            case .skySwitchTapped:
                state.idleSeconds = 0
                guard !state.isSkyAnimating else { return .none }
                let target: KidLook = state.look == .day ? .night : .day
                state.skyOverride = target == state.plannedLook ? nil : target
                state.isSkyAnimating = true
                return .run { [clock] send in
                    try await clock.sleep(for: .milliseconds(1200))
                    await send(.skyAnimationEnded)
                }

            case .skyAnimationEnded:
                state.isSkyAnimating = false
                return .none

            case .touched:
                state.idleSeconds = 0
                return .none

            case let .slotTapped(start):
                state.idleSeconds = 0
                guard !state.isPlaying else { return .none }
                state.plays[start, default: 0] += 1
                state.isPlaying = true
                return .run { [clock] send in
                    try await clock.sleep(for: .milliseconds(1200))
                    await send(.playEnded)
                }

            case .playEnded:
                state.isPlaying = false
                return .none
            }
        }
    }

    private func minute(of date: Date) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
