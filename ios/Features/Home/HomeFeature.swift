import AppSettings
import BusClient
import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import HolidayProvider
import KitArt
import Localization
import ScheduleStore
import SchoolDirectory
import Strings

/// The kids' home screen: each kid's slots for today and the time now (boards A1, E1, E3).
@Reducer
public struct HomeFeature {
    /// Kid A's block on the right panel (spec "Now and next on home").
    /// ux-states: home, Kid A block
    public enum KidABlock: Equatable, Sendable {
        /// A1 / A1m / E1: "Leave in" with the way picture and the minutes to the leave time.
        case leave
        /// A1n: "Bed in" and the time left, then tomorrow's outing (no Next row: it would be Sleep).
        case bedTime(HomeModel.TimeLeft, tomorrow: TomorrowRow?)
        /// E3 / E3b: the one Next row ("in 45 min" within the hour, else "at 2:00 pm"; layout v68).
        case next(NextItem)
        /// Nothing next today: the row is left out (spec E3 "No item left today").
        case nothing
    }

    public struct KidDay: Equatable, Sendable {
        public var kid: Kid
        public var dayType: DayType
        public var slots: [Slot]
        /// From the template's evening routine to wake-up (board A1n); `nil` keeps the day look.
        public var night: NightSpan? = nil
        /// Tomorrow's first outing (board A1n "Tomorrow" row); `nil` when tomorrow has none.
        public var tomorrow: Outing? = nil
        /// Tomorrow's slots: Kid B's Next row at night goes on to the first thing after wake-up (A1n).
        public var tomorrowSlots: [Slot] = []
        /// The kid's routine missions (C5).
        public var missions: [Mission] = []

        /// Spec "Mission windows": the day's stretches for missions.
        public var windows: [WindowSpan] { DayPlanner.missionWindows(slots: slots, night: night) }

        public init(kid: Kid, dayType: DayType, slots: [Slot], night: NightSpan? = nil, tomorrow: Outing? = nil,
                    tomorrowSlots: [Slot] = [], missions: [Mission] = []) {
            self.kid = kid
            self.dayType = dayType
            self.slots = slots
            self.night = night
            self.tomorrow = tomorrow
            self.tomorrowSlots = tomorrowSlots
            self.missions = missions
        }
    }

    /// The open window of the first kid who has missions in it, and the part the label names.
    struct OpenWindow: Equatable {
        var day: KidDay
        var part: MissionWindow
    }

    @ObservableState
    public struct State: Equatable {
        public var today: Day?
        /// Today's weekday in the app's calendar (set with `today`).
        public var weekday: Weekday?
        public var minute = 0
        /// One entry per kid, in the order the store keeps them. Empty when nothing could be loaded.
        public var days: [KidDay] = []
        /// Every word this screen shows comes from here (views hold no values).
        public var strings = Localizer.injected

        public init() {}

        /// "Saturday" (E3), from the app's calendar, never the device's.
        public var dayName: String? { weekday.map(DayText.name) }

        /// The sky switch's choice (board 0g): it lasts until the next planned change of look.
        public var skyOverride: KidLook?
        /// True for the 1.2 s of the switch animation; taps meanwhile are ignored.
        public var isSkyAnimating = false
        /// Seconds since the last touch, counted in the root's 1-second ticks (never from the date).
        public var idleSeconds = 0
        /// The slice the 2-second hold started on (spec "No empty slice card"): grown-up mode opens with it picked.
        public var heldSlotStart: Int?
        /// The day pending school changes were last applied (G7).
        public var pendingSchoolsAppliedOn: Day?
        /// Board 0g2 idle wink: one more each time 20 s pass without a touch.
        public var winks = 0
        /// Spec "Picture rigs": a play id per drawn slot start; a slot plays when its id goes up.
        public var plays: [Int: Int] = [:]
        /// Slots playing now (1.2 s each). Every tapped picture plays at once (user, 2026-11-09); a
        /// tap on a picture that is still playing does not restart it.
        public var playing: Set<Int> = []

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

        /// Spec "Hub text" (layout v71, board E3h): today is a public holiday; the weekday turns red.
        public var isPublicHoliday = false
        /// Today's public holiday's name ("Deepavali"), from the bundled list.
        public var holidayName: String?
        /// The name of Kid A's (the clock kid's) school break today ("June holidays").
        public var breakName: String?

        /// The right panel's first line (spec "Hub text"): always the full weekday.
        public var dayHeading: String? { dayName }

        /// The caption under the weekday (spec "Hub text", board E3h): the public holiday's name, else
        /// on a weekday (spec E3 "Weekday school holiday") the name of Kid A's school break. The only
        /// holiday sign on the kid screen; nil leaves the line out.
        public var dayNote: String? {
            if isPublicHoliday { return holidayName }
            guard let weekday, Weekday.schoolDays.contains(weekday) else { return nil }
            return breakName
        }

        /// The name line pushes the rest of the panel down by its 32 (`HomeLayout(dayNote:)`).
        public var hasDayNote: Bool { dayNote != nil }

        /// Every kid's items today, for the missions and Bring of their outings.
        public var items: [ScheduleItem] = []

        /// Spec "Mission windows": the first kid whose open window has missions, and the first part
        /// with missions in it (the morning runs from wake-up to the first leave, or noon).
        var openWindow: OpenWindow? {
            for day in days {
                guard let span = DayPlanner.window(at: minute, in: day.windows) else { continue }
                let list = DayPlanner.missions(in: span, routine: day.missions, items: items, weekday: weekday ?? .monday,
                                               schoolBring: day.kid.school?.bring ?? [])
                if let part = list.first?.window { return OpenWindow(day: day, part: part) }
            }
            return nil
        }

        /// Home offers the missions button while a kid's open window has missions.
        public var showsMissions: Bool { openWindow != nil }

        /// The button's label (spec "Home button label per window"): "Missions", "Before Swimming"; a
        /// name too long for one line falls back to "Missions".
        public var missionsTitle: String {
            guard let open = openWindow else { return strings.tr("home.missions") }
            let label: String
            switch open.part {
            case let .before(event): label = strings.tr("home.missions.before", title(of: event, in: open.day))
            case .morning, .evening: return strings.tr("home.missions")
            }
            return label.count <= Self.longestMissionsTitle ? label : strings.tr("home.missions")
        }

        /// The most characters that fit the 382 button with its arrow in head type.
        static let longestMissionsTitle = 16

        private func title(of event: EventRef, in day: KidDay) -> String {
            day.slots.first { EventRef($0) == event }?.title ?? ""
        }

        /// Kid A's outing that the open window leads to, when it starts within 3 hours.
        public var morningOuting: Outing? {
            guard let first = days.first, let outing = DayPlanner.window(at: minute, in: first.windows)?.outing,
                  outing.slot.start - minute <= 180 else { return nil }
            return outing
        }

        /// "Leave in" (spec A1m, v132): the countdown runs to the outing's leave time.
        public var outingHeading: String? { morningOuting.map { _ in strings.tr("missions.leave_in") } }

        /// Minutes until Kid A leaves: to the chosen bus with live times, else to start − leave before.
        public var minutesToLeave: Int? {
            guard let outing = morningOuting else { return nil }
            if let leaveIn = live?.leaveIn { return max(leaveIn, 0) }
            return max(outing.leave - minute, 0)
        }

        /// Kid A's bus route (C2) and the last good live answer (spec "A2 live look", A1 line).
        public var busPlan: BusPlan?
        public var arrivals: [BusArrival]?
        public var arrivalsAt: Date?
        public var now: Date?
        public var secondsSinceRefresh = 0

        /// Live numbers for Kid A's bus outing while the answer is under 2 minutes old.
        public var live: LiveMorning? {
            guard let outing = morningOuting, outing.trip.way == .bus, let busPlan, !busPlan.routes.isEmpty,
                  let arrivals, let arrivalsAt,
                  let now, now.timeIntervalSince(arrivalsAt) < 120 else { return nil }
            return LiveMorning(arrivals: arrivals, plan: busPlan, minute: minute, start: outing.slot.start)
        }

        /// The status under the minutes, only with live times: "On time", "Leave now!", "Ask a grown-up".
        public var status: (text: String, tone: StatusDot.Tone)? {
            switch live?.status {
            case .onTime?: (strings.tr("missions.status.on_time"), .onTime)
            case .leaveNow?: (strings.tr("missions.status.leave_now"), .hurry)
            case .askGrownup?: (strings.tr("missions.status.ask"), .quiet)
            case nil: nil
            }
        }

        /// Live times are fetched only for Kid A's next bus outing in an open window.
        /// A bus morning with a route that has buses: an empty route never calls LTA.
        var wantsLive: Bool { morningOuting?.trip.way == .bus && !(busPlan?.routes.isEmpty ?? true) }

        public var kidABlock: KidABlock {
            guard let first = days.first else { return .nothing }
            if morningOuting != nil { return .leave }
            guard let next = HomeModel.next(first.slots, minute: minute) else { return .nothing }
            // Spec "Kid A, which row": one row only; the item it names shows once (no time left
            // block over a second row for the same thing).
            if !showsMissions, let left = HomeModel.bedIn(to: next, minute: minute) {
                return .bedTime(left, tomorrow: first.tomorrow.map(TomorrowRow.init))
            }
            return .next(next)
        }

        /// The last part of Kid A's block; Kid B's block hangs 40 below it (layout v17).
        public var kidAEnd: HomeLayout.KidAEnd {
            switch kidABlock {
            case .leave: status == nil ? .timeLeft : .status
            case let .bedTime(_, tomorrow): tomorrow == nil ? .timeLeft : .timeLeftRow
            case .next: .nextRow
            case .nothing: .name
            }
        }

        /// E1 (one kid): the Next row stays under "On time" on a leaving morning and names the next
        /// thing other than the outing's item (a Breakfast before leaving stays), so the item shows
        /// once (layout v70).
        public var leaveNext: NextItem? {
            guard days.count == 1, kidABlock == .leave, let first = days.first else { return nil }
            return HomeModel.next(first.slots, minute: minute, skipping: morningOuting?.slot)
        }

        // MARK: What the view shows (it holds no values of its own)

        /// Kid A's slots, drawn on the clock (none before the family loads).
        public var clockSlots: [Slot] { days.first?.slots ?? [] }
        public var clockSectors: [ClockSector] { HomeModel.sectors(clockSlots, minute: minute) }
        public var clockHub: PieClock.Hub { HomeModel.hub(clockSlots, minute: minute) }
        /// The hand, only when there is a day to point into.
        public var clockHand: Int? { clockSlots.isEmpty ? nil : minute }

        /// A1 / A1m: "Leave in" over the minutes to leave, while Kid A's outing is near.
        public var leaveTimeLeft: HomeModel.TimeLeft? {
            guard let heading = outingHeading, let minutes = minutesToLeave else { return nil }
            return HomeModel.TimeLeft(label: heading, minutes: minutes)
        }

        /// The second kid's Now row and Next row (layout v68, spec "Kid B block"); the Next row is
        /// left out when nothing is next. Next follows the same rule as Kid A's, so it never names
        /// what is on now.
        public struct KidBRows: Equatable, Sendable {
            public var kid: Kid
            public var now: NowItem
            public var next: NextItem?
        }

        public var kidB: KidBRows? {
            guard days.count > 1 else { return nil }
            let day = days[1]
            return KidBRows(kid: day.kid, now: HomeModel.now(day.slots, minute: minute, tomorrow: day.tomorrowSlots),
                            next: HomeModel.next(day.slots, minute: minute, tomorrow: day.tomorrowSlots))
        }

        /// Kid B's Now row caption.
        public var nowLabel: String { strings.tr("home.now") }

        /// A1 / A1m: the way picture beside "Leave in" (the bus, the car, ...).
        public var leavePicture: KitSlot? { morningOuting.map { KitSlot(iconName: $0.trip.way.moverPicture) } }

        /// The Next row's caption (Kid A's and Kid B's).
        public var nextLabel: String { strings.tr("home.next") }
    }

    public enum Action: Equatable {
        case task
        case tick(Date)
        case reload
        /// The family and its year (each kid's school calendar and the public holidays).
        case loaded(ScheduleSnapshot?, family: FamilyCalendar)
        /// A press on the clock began on the slice starting at this minute (nil: off the slices).
        case clockPressed(slotStart: Int?)
        /// The clock was held for 2 seconds; the app opens the grown-up lock.
        case clockHoldCompleted
        /// Board G0: the pencil; the app opens the grown-up lock.
        case pencilTapped
        /// Board G0 (layout v71): the calendar button; the app opens the school calendar (K1), no lock.
        case calendarTapped
        /// The kid tapped the day/night switch (board 0g).
        case skySwitchTapped
        case skyAnimationEnded
        /// Any touch on the kid screen; it restarts the idle count.
        case touched
        /// The kid tapped the drawn slot that starts at this minute.
        case slotTapped(Int)
        case playEnded(Int)
        /// "Missions →" in a mission window; the app opens the missions screen.
        case missionsTapped
        case refresh
        case arrivalsLoaded([BusArrival]?, at: Date)
    }

    @Dependency(\.calendar) var calendar
    @Dependency(\.date) var date
    @Dependency(\.continuousClock) var clock
    @Dependency(\.scheduleStore) var scheduleStore
    @Dependency(\.holidays) var holidays
    @Dependency(\.schoolDirectory) var schoolDirectory
    @Dependency(\.bus) var bus

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
                state.now = now
                state.secondsSinceRefresh += 1
                // Live times every 30 s on a bus morning (the tick comes every second from the root).
                let refresh: Effect<Action> = state.wantsLive && state.secondsSinceRefresh >= 30 ? .send(.refresh) : .none
                // The next planned change (evening routine, wake-up) clears the switch's choice.
                if state.plannedLook != planned { state.skyOverride = nil }
                // Before the first load `.task` sets the day; only a real day change reloads.
                guard let today = state.today, day != today else { return refresh }
                state.today = day
                state.weekday = day.weekday(calendar)
                return .merge(refresh, .send(.reload))

            case .refresh:
                state.secondsSinceRefresh = 0
                // S4 "Live bus times" off: no LTA call; home shows the timetable look.
                guard state.wantsLive, let plan = state.busPlan else { return .none }
                return .run { [bus, date] send in
                    let arrivals = try? await bus.arrivals(plan.stop)
                    await send(.arrivalsLoaded(arrivals, at: date.now))
                }

            case let .arrivalsLoaded(arrivals, at):
                guard let arrivals else { return .none }
                state.arrivals = arrivals
                state.arrivalsAt = at
                state.now = at
                return .none

            case .reload:
                guard let year = state.today?.year else { return .none }
                return .run { [scheduleStore, holidays, schoolDirectory] send in
                    let snapshot = try? await scheduleStore.load()
                    let list = await holidays.holidays(year)
                    let family = await schoolDirectory.family(
                        kids: snapshot?.kids ?? [], publicHolidays: list.map(\.day),
                        holidayNames: Dictionary(list.map { ($0.day, $0.name) }, uniquingKeysWith: { first, _ in first }))
                    await send(.loaded(snapshot, family: family))
                }

            case let .loaded(snapshot, family):
                guard let snapshot, let today = state.today else {
                    state.days = []
                    state.isPublicHoliday = false
                    state.holidayName = nil
                    state.breakName = nil
                    return .none
                }
                // G7 / G4: a school move or hours change whose day has come becomes the record, then the day reloads.
                let due = snapshot.kids.filter { $0.applyingWaitingChanges(on: today) != $0 }
                if !due.isEmpty, state.pendingSchoolsAppliedOn != today {
                    // Once a day, so a failed save cannot reload for ever.
                    state.pendingSchoolsAppliedOn = today
                    let routines = snapshot.routines
                    return .run { [scheduleStore] send in
                        for kid in due {
                            // Waiting School hours go into that day's and later templates first (#255), then
                            // the record, only when every template saved: a template left on the old slot
                            // would no longer follow the new record and would keep the old time for good.
                            // While the change still waits, every reader reads it by date, so a retry is safe.
                            do {
                                for routine in Set(kid.readingWaitingHours(routines)).subtracting(routines) {
                                    try await scheduleStore.saveRoutine(routine)
                                }
                                try await scheduleStore.saveKid(kid.applyingWaitingChanges(on: today))
                            } catch {
                                continue
                            }
                        }
                        await send(.reload)
                    }
                }
                let items = family.resolving(snapshot.items, calendar: calendar)
                state.days = snapshot.kids.map { kid in
                    let holidayDays = family.daysOff(kid.id)
                    let routines = kid.readingWaitingHours(snapshot.routines)
                    let tomorrow = DayPlanner.slots(on: today.adding(days: 1, calendar: calendar), kid: kid,
                                                    routines: routines, items: items,
                                                    holidays: holidayDays, calendar: calendar)
                    return KidDay(kid: kid,
                                  dayType: DayPlanner.dayType(on: today, holidays: holidayDays, calendar: calendar),
                                  slots: DayPlanner.slots(on: today, kid: kid, routines: routines,
                                                          items: items, holidays: holidayDays, calendar: calendar),
                                  night: DayPlanner.nightSpan(of: DayPlanner.template(
                                      for: kid.id, on: today, routines: routines, holidays: holidayDays,
                                      calendar: calendar)),
                                  tomorrow: DayPlanner.nextOuting(in: tomorrow, after: -1),
                                  tomorrowSlots: tomorrow,
                                  missions: snapshot.missions.filter { $0.kid == kid.id })
                }
                state.items = items
                state.isPublicHoliday = family.publicHolidays.contains(today)
                state.holidayName = family.holidayName(on: today)
                state.breakName = snapshot.kids.first.flatMap { family.breakName($0.id, on: today) }
                state.busPlan = snapshot.kids.first.flatMap { kid in
                    snapshot.busPlans.route(kid: kid.id)?.graced(by: kid)
                }
                return state.wantsLive ? .send(.refresh) : .none

            case let .clockPressed(start):
                state.heldSlotStart = start
                return .none

            case .pencilTapped:
                state.heldSlotStart = nil
                return .none

            case .calendarTapped:
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
                guard !state.playing.contains(start) else { return .none }
                state.plays[start, default: 0] += 1
                state.playing.insert(start)
                return .run { [clock] send in
                    try await clock.sleep(for: .milliseconds(1200))
                    await send(.playEnded(start))
                }

            case let .playEnded(start):
                state.playing.remove(start)
                return .none

            case .missionsTapped:
                return .none
            }
        }
    }

    private func minute(of date: Date) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
