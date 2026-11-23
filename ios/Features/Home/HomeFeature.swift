import AppSettings
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

/// The kids' home screen (spec A1, layout v75): the picked kid's 24-hour clock and the family's next
/// things, nearest at the bottom over the kid chips (boards A1, A1m, A1b, A1n, A1z, A1k, E1, E3).
@Reducer
public struct HomeFeature {
    public struct KidDay: Equatable, Sendable {
        public var kid: Kid
        public var dayType: DayType
        public var slots: [Slot]
        /// From the template's evening routine to wake-up (board A1n); `nil` keeps the day look.
        public var night: NightSpan? = nil
        /// The Tomorrow row (boards A1n, A1z): the next day with a plan within 14 days; `nil` when
        /// nothing is planned in them.
        public var ahead: AheadRow? = nil
        /// Tomorrow's slots: Kid B's Next row at night goes on to the first thing after wake-up (A1n).
        public var tomorrowSlots: [Slot] = []
        /// The kid's routine missions (C5).
        public var missions: [Mission] = []

        /// Spec "Mission windows": the day's stretches for missions.
        public var windows: [WindowSpan] { DayPlanner.missionWindows(slots: slots, night: night) }

        public init(kid: Kid, dayType: DayType, slots: [Slot], night: NightSpan? = nil, ahead: AheadRow? = nil,
                    tomorrowSlots: [Slot] = [], missions: [Mission] = []) {
            self.kid = kid
            self.dayType = dayType
            self.slots = slots
            self.night = night
            self.ahead = ahead
            self.tomorrowSlots = tomorrowSlots
            self.missions = missions
        }
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

        /// Board 0g2 on the hour: the hand's disc pulses when this changes.
        public var hour: Int { minute / 60 }

        /// Spec A1 "Hub": today is a public holiday; the weekday turns red and its name sits under the time.
        public var isPublicHoliday = false
        /// Today's public holiday's name ("Deepavali"), from the bundled list.
        public var holidayName: String?

        /// Every kid's items today, for the missions and Bring of their outings.
        public var items: [ScheduleItem] = []

        /// Spec A1 "Next things": the family's next things, nearest first (worked out on every load
        /// and tick with the app's calendar).
        public var things: [NextThing] = []

        /// Spec A1 "Kid chips": the kid a chip tap picked; the clock goes back to the next card's kid
        /// 10 s after the last touch, and at once when the next card's kid changes.
        public var tappedKid: Kid.ID?
        /// The next card's kid when the chip was tapped.
        public var tappedCardKid: Kid.ID?

        /// Spec A1 "Mission rows" (design, 2026-11-23): each outing has its own list, its Bring (School's
        /// own Bring, or the item's), and on the day's first outing the kid's morning routine missions
        /// too. An outing whose list is not empty is a mission row.
        func missionOutings(_ day: KidDay) -> [Slot] {
            guard let weekday else { return [] }
            let outings = day.slots.filter { $0.trip != nil }
            let routine = day.missions.contains { $0.days.contains(weekday) }
            return outings.enumerated().compactMap { index, slot in
                let bring: [ItemMission] = switch slot.source {
                case .routine: slot.kind == .school ? day.kid.school?.bring ?? [] : []
                case let .weekly(id), let .once(id): items.first { $0.id == id }?.bring ?? []
                }
                return !bring.isEmpty || (index == 0 && routine) ? slot : nil
            }
        }

        // MARK: What the view shows (it holds no values of its own)

        /// The nearest thing: the next card, 24 above the chips.
        public var nextCard: NextThing? { things.first }
        /// The later things that fit above the card (spec A1 "Items": the farthest drop off the top).
        public var laterRows: [NextThing] {
            let later = Array(things.dropFirst())
            return Array(later.prefix(HomeLayout.rowsThatFit(later.map(\.isMission))))
        }

        /// Which later rows are mission rows (taller), nearest first: `HomeLayout.row(_:of:)` places them.
        public var laterRowKinds: [Bool] { laterRows.map(\.isMission) }

        /// Whose day the clock shows: the tapped kid, else the next card's first kid, else the first kid.
        public var clockKid: Kid.ID? { tappedKid ?? nextCard?.kids.first ?? days.first?.kid.id }
        public var clockDay: KidDay? { days.first { $0.kid.id == clockKid } ?? days.first }

        /// The clock kid's slots, drawn on the clock (none before the family loads).
        public var clockSlots: [Slot] { clockDay?.slots ?? [] }
        public var clockSectors: [ClockSector] { HomeModel.sectors(clockSlots, minute: minute) }
        /// The hand, only when there is a day to point into.
        public var clockHand: Int? { clockSlots.isEmpty ? nil : minute }
        /// The rim in the clock kid's colour.
        public var clockRim: Int? { clockDay?.kid.colorIndex }
        /// Spec A1 "Hub": the clock kid's face, the full weekday and the time; on a public holiday the
        /// weekday is red with the holiday's name under the time, and no face.
        public var clockHub: PieClock.Hub {
            PieClock.Hub(face: isPublicHoliday ? nil : clockDay.map { KidFace.Badge(face: $0.kid.face, colorIndex: $0.kid.colorIndex) },
                         weekday: dayName ?? "", time: TimeText.clock(minute), period: TimeText.period(minute),
                         holiday: isPublicHoliday ? holidayName : nil)
        }

        /// Board 0g2 new slot: the clock kid's current slot's start; when it changes, its picture hops.
        public var currentSlotStart: Int? { DayPlanner.now(at: minute, in: clockSlots).current?.start }

        /// One kid chip (spec A1 "Kid chips").
        public struct Chip: Equatable, Identifiable, Sendable {
            public var id: Kid.ID
            public var face: KidFace.Badge
            /// What the kid is doing now (the play picture with nothing planned now).
            public var picture: KitSlot
            /// Only with one kid (board E1).
            public var name: String?
            public var isPicked: Bool
        }

        /// The chips' fit by the number of kids (design answer, 2026-11-23): three compact, four the face alone.
        public var chipFit: KidChip.Fit {
            switch days.count {
            case ...2: .regular
            case 3: .compact
            default: .faceOnly
            }
        }

        public var chips: [Chip] {
            days.map { day in
                let current = DayPlanner.now(at: minute, in: day.slots).current
                let picture = current.flatMap { $0.kind == .free ? nil : KitSlot(iconName: $0.iconName) } ?? .actPlay
                return Chip(id: day.kid.id, face: KidFace.Badge(face: day.kid.face, colorIndex: day.kid.colorIndex),
                            picture: picture, name: days.count == 1 ? day.kid.name : nil,
                            isPicked: day.kid.id == clockKid)
            }
        }

        /// Spec A1 "The time cell": within 60 minutes "{n} min" over the dots (one red per 10 minutes
        /// left, rounded up); later today the clock time; another day "Tomorrow" / the weekday (2–6
        /// days) / "Tue 1 Dec" (7 and more) over the time.
        public func timeCell(_ thing: NextThing) -> TimeCellContent {
            guard thing.inDays == 0 else {
                let label = switch thing.inDays {
                case ...1: strings.tr("home.tomorrow")
                case 2...6: DayText.name(thing.weekday)
                default: DayText.short(thing.day, weekday: thing.weekday)
                }
                return .day(label: label, time: TimeText.withPeriod(thing.act))
            }
            let left = max(thing.act - minute, 0)
            guard left <= 60 else { return .at(time: TimeText.clock(thing.act), period: TimeText.period(thing.act)) }
            return .soon(number: "\(left)", unit: strings.tr("home.min"), dots: (left + 9) / 10)
        }

        /// The kids' faces under a row's title, in family order.
        public func faces(_ thing: NextThing) -> [KidFace.Badge] {
            thing.kids.compactMap { id in
                days.first { $0.kid.id == id }.map { KidFace.Badge(face: $0.kid.face, colorIndex: $0.kid.colorIndex) }
            }
        }

        /// A mission row's hatch: the kid's colour, or the shared one for an outing of two or more kids.
        public func hatch(_ thing: NextThing) -> NextThingRow.Hatch? {
            guard thing.isMission else { return nil }
            guard thing.kids.count == 1, let kid = days.first(where: { $0.kid.id == thing.kids[0] }) else { return .shared }
            return .kid(kid.kid.colorIndex)
        }

        /// For 10 s after a chip tap the other kids' rows drop to 30 %.
        public func isFaded(_ thing: NextThing) -> Bool {
            guard let tappedKid else { return false }
            return !thing.kids.contains(tappedKid)
        }
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
        /// Board G0 (layout v75): the calendar button; the app opens the school calendar (K1), no lock.
        case calendarTapped
        /// The kid tapped the day/night switch (board 0g).
        case skySwitchTapped
        case skyAnimationEnded
        /// Any touch on the kid screen; it restarts the idle count.
        case touched
        /// The kid tapped the drawn slot that starts at this minute.
        case slotTapped(Int)
        case playEnded(Int)
        /// Opens the missions screen (the driver's "missionsTapped"); the app opens A2.
        case missionsTapped
        /// Spec A1 "Mission rows": a mission row or card for this kid; the app opens A2 for that kid.
        case missionRowTapped(Kid.ID)
        /// Spec A1 "Kid chips": the clock turns to this kid's day and the others' rows fade for 10 s.
        case kidChipTapped(Kid.ID)
        /// 10 s passed after the last touch: back to the family view.
        case chipTimeUp
    }

    private enum ChipID: Hashable { case timer }

    @Dependency(\.calendar) var calendar
    @Dependency(\.date) var date
    @Dependency(\.continuousClock) var clock
    @Dependency(\.scheduleStore) var scheduleStore
    @Dependency(\.holidays) var holidays
    @Dependency(\.schoolDirectory) var schoolDirectory

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

            case let .kidChipTapped(kid):
                state.idleSeconds = 0
                // One kid (board E1): the chip does nothing.
                guard state.days.count > 1 else { return .none }
                state.tappedKid = kid
                state.tappedCardKid = state.nextCard?.kids.first
                return chipTimer

            case .chipTimeUp:
                state.tappedKid = nil
                state.tappedCardKid = nil
                return .none

            case .missionRowTapped:
                state.idleSeconds = 0
                return .none

            case let .tick(now):
                state.idleSeconds += 1
                if state.idleSeconds >= 20 {
                    state.idleSeconds = 0
                    state.winks += 1
                }
                let day = Day(now, calendar: calendar)
                let planned = state.plannedLook
                let newMinute = self.minute(of: now)
                // The next planned change (evening routine, wake-up) clears the switch's choice.
                let changed = newMinute != state.minute
                state.minute = newMinute
                if state.plannedLook != planned { state.skyOverride = nil }
                let follow: Effect<Action> = changed ? listChanged(&state) : .none
                // Before the first load `.task` sets the day; only a real day change reloads.
                guard let today = state.today, day != today else { return follow }
                state.today = day
                state.weekday = day.weekday(calendar)
                return .merge(follow, .send(.reload))

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
                    state.things = []
                    state.isPublicHoliday = false
                    state.holidayName = nil
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
                                  ahead: aheadRow(kid: kid, today: today, tomorrow: tomorrow, routines: routines,
                                                  items: items, holidays: holidayDays),
                                  tomorrowSlots: tomorrow,
                                  missions: snapshot.missions.filter { $0.kid == kid.id })
                }
                state.items = items
                state.isPublicHoliday = family.publicHolidays.contains(today)
                state.holidayName = family.holidayName(on: today)
                return listChanged(&state)

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
                // A touch while a chip is picked restarts its 10 s.
                return state.tappedKid == nil ? .none : chipTimer

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

    /// Spec A1 "Kid chips": back to the family view 10 s after the last touch.
    private var chipTimer: Effect<Action> {
        .run { [clock] send in
            try await clock.sleep(for: .seconds(10))
            await send(.chipTimeUp)
        }
        .cancellable(id: ChipID.timer, cancelInFlight: true)
    }

    /// Works the family's next things out again; a tapped chip lets go at once when the next card's
    /// kid changes (spec A1 "Pie clock").
    private func listChanged(_ state: inout State) -> Effect<Action> {
        guard let today = state.today else { return .none }
        let days = state.days.map { day in
            HomeNext.KidDay(kid: day.kid.id, today: day.slots, tomorrow: day.tomorrowSlots, ahead: day.ahead,
                            missionOutings: state.missionOutings(day))
        }
        state.things = HomeNext.things(days, minute: state.minute, today: today, calendar: calendar)
        guard state.tappedKid != nil, state.nextCard?.kids.first != state.tappedCardKid else { return .none }
        state.tappedKid = nil
        state.tappedCardKid = nil
        return .cancel(id: ChipID.timer)
    }

    /// Spec "Kid A, which row" (layout v74): the first of the next 14 days with something to name.
    private func aheadRow(kid: Kid, today: Day, tomorrow: [Slot], routines: [Routine], items: [ScheduleItem],
                          holidays: Set<Day>) -> AheadRow? {
        for offset in 1...14 {
            let day = today.adding(days: offset, calendar: calendar)
            let slots = offset == 1 ? tomorrow : DayPlanner.slots(on: day, kid: kid, routines: routines, items: items,
                                                                  holidays: holidays, calendar: calendar)
            if let item = HomeModel.dayAhead(slots) {
                return AheadRow(item: item, inDays: offset, day: day, weekday: day.weekday(calendar))
            }
        }
        return nil
    }

    private func minute(of date: Date) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
