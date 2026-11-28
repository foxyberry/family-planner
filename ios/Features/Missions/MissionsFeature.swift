import AppSettings
import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import BusClient
import HolidayProvider
import Localization
import KitArt
import ScheduleStore
import SchoolDirectory
import Strings

/// A2-MVP · Morning missions (spec "A2-MVP", "MVP data"): the way to the chosen kid's next outing,
/// the kid list, the chosen kid's mission circles and the slide. Kids are never locked: missions
/// only help, the slide is always on.
@Reducer
public struct MissionsFeature {
    /// One place in the mission row: a mission, the done ones folded into one ✓, or "+n" for the next page.
    public enum Circle: Equatable, Sendable, Identifiable {
        case mission(WindowMission, isDone: Bool, isCurrent: Bool)
        case folded(count: Int)
        case more(count: Int)
        /// On the last page: "‹" back to the first page.
        case back

        public var id: String {
            switch self {
            case let .mission(mission, _, _): mission.id.uuidString
            case .folded: "folded"
            case .more: "more"
            case .back: "back"
            }
        }
    }

    public struct Done: Equatable, Sendable {
        public var medal: MedalKind?
        public var title: String
        public var subtitle: String?
        /// With no medal (no time rule: no outing, or slid after L2), the crown instead of a check
        /// (user, 2026-11-09; spec A3r).
        public var prize: KitSlot { .crown }
    }

    /// The header's right side: "Leave in" / "{Place} in", the minutes, and the live status.
    public struct Header: Equatable, Sendable {
        /// "Leave in"; nil when no bus can be caught (the status alone says "Ask a grown-up").
        public var label: String?
        public var minutes: String
        public var status: StatusLine?
    }

    public struct StatusLine: Equatable, Sendable {
        public enum Tone: Equatable, Sendable { case onTime, hurry, quiet }
        public var text: String
        public var tone: Tone
    }

    public struct KidRow: Equatable, Sendable, Identifiable {
        public var kid: Kid
        public var done: Int
        public var total: Int
        public var isReady: Bool
        /// The medal on the ring after sliding (board A3); nil before, or for "Ready!" with no medal.
        public var medal: MedalKind? = nil
        /// The chosen kid's row sits on its band (a crayon on-state: its words stay ink at night).
        public var isChosen = false
        public var id: Kid.ID { kid.id }
        public var progress: Double { isReady ? 1 : total == 0 ? 0 : Double(done) / Double(total) }
    }

    /// The way strip's content for the chosen kid's next outing.
    public struct Way: Equatable, Sendable {
        public var destination: String
        public var mover: String
        /// The mover's x on the strip board (spec "Timetable look, mover").
        public var moverX: CGFloat
        public var homeLabel: String
        public var showsStops: Bool
        public var cardTitle: String
        public var cardCaption: String
        /// The destination's name under its stop ("School").
        public var place: String
        /// Whose outing it is: the card starts with this kid's face.
        public var owner: Kid
    }

    @ObservableState
    public struct State: Equatable {
        /// Day or night (board A2 night), the kid home's look; the app keeps it in step.
        public var look: KidLook = .day
        public var today: Day?
        /// The day's weekday, for the weekend greeting (board A2t-w).
        public var weekday: Weekday?
        public var minute = 0
        public var kids: [Kid] = []
        public var missions: [Mission] = []
        public var slots: [Kid.ID: [Slot]] = [:]
        public var items: [ScheduleItem] = []
        /// Each kid's list when the screen opened (spec "Event lists", A2): the opened event's before
        /// list, or else the kid's nearest one whose time has not passed. It stays while the screen is
        /// open, so leaving does not empty the list.
        public var spans: [Kid.ID: WindowSpan] = [:]
        /// The event each kid's list belongs to.
        public var listSlots: [Kid.ID: Slot] = [:]
        /// The event a home row opened (spec A2 "Opened from a row"); nil opens each kid's nearest list.
        public var opened: ListRef?
        public var bundles: [MissionBundle] = []
        public var days: [Kid.ID: MissionDay] = [:]
        public var chosen: Kid.ID?
        public var page = 0
        /// Each kid's bus route (C2).
        public var busPlans: [Kid.ID: BusPlan] = [:]
        /// The last good live answer and when it came (spec "Refresh").
        public var arrivals: [BusArrival]?
        public var arrivalsAt: Date?
        public var now: Date?
        /// "Not yet" asks once before a ready kid is undone.

        /// Every word this screen shows comes from here (views hold no values).
        public var strings = Localizer.injected

        public init(look: KidLook = .day) {
            self.look = look
        }

        public var chosenKid: Kid? { kids.first { $0.id == chosen } }

        /// The kid's circles in their window: the routine's missions for today, then the outing's
        /// "before" missions and Bring, or the "after" missions of what just ended.
        public func list(of kid: Kid.ID) -> [WindowMission] {
            guard let span = spans[kid], let part = span.parts.first, let slot = listSlots[kid] else { return [] }
            return EventListRules.before(kid: kid, slot: slot, in: slots[kid] ?? [], bundles: bundles,
                                         weekday: weekday ?? .monday)
                .map { WindowMission(window: part, id: $0.id, name: $0.name, picture: $0.picture) }
        }

        /// The event of the outing the kid's window leads to, which the slide belongs to (nil: the
        /// window's own "All done? Slide!").
        public func outingEvent(of kid: Kid.ID) -> EventRef? {
            spans[kid]?.outing.flatMap { EventRef($0.slot) }
        }

        /// Each kid's events today whose before list is not empty, in time order.
        static func listEvents(kid: Kid.ID, slots: [Slot], bundles: [MissionBundle], weekday: Weekday) -> [Slot] {
            slots.filter { !EventListRules.before(kid: kid, slot: $0, in: slots, bundles: bundles, weekday: weekday).isEmpty }
                .sorted { $0.start < $1.start }
        }

        /// Each kid's list event: the opened one when the kid has it (a kid without it is left out),
        /// else the nearest whose leave time (start, with no trip) is still ahead.
        static func listSlots(_ slots: [Kid.ID: [Slot]], bundles: [MissionBundle], weekday: Weekday, minute: Int,
                              opened: ListRef?) -> [Kid.ID: Slot] {
            Dictionary(uniqueKeysWithValues: slots.compactMap { kid, slots in
                let events = listEvents(kid: kid, slots: slots, bundles: bundles, weekday: weekday)
                let slot: Slot? = if let opened { events.first { ListRef($0, in: slots) == opened } }
                    else { events.first { event in (event.trip.map { event.start - $0.leaveBefore } ?? event.start) > minute } }
                return slot.map { (kid, $0) }
            })
        }

        /// A kid's list as a span: the list's record, and the outing whose slide it carries.
        static func span(for slot: Slot, in slots: [Slot]) -> WindowSpan {
            WindowSpan(start: 0, end: slot.start, parts: [MissionWindow.before(ListRef(slot, in: slots))],
                       outing: slot.trip.map { Outing(slot: slot, trip: $0) })
        }

        public func day(of kid: Kid.ID) -> MissionDay {
            days[kid] ?? MissionDay(kid: kid, date: today ?? Day(year: 2000, month: 1, day: 1))
        }

        public var rows: [KidRow] {
            kids.map { kid in
                let list = list(of: kid.id), day = day(of: kid.id)
                return KidRow(kid: kid, done: list.filter { day.done.contains($0.id) }.count, total: list.count,
                              isReady: day.ready, medal: day.ready ? Self.medalKind(day.medal) : nil,
                              isChosen: kid.id == chosen)
            }
        }

        static func medalKind(_ medal: MorningMedal?) -> MedalKind? {
            switch medal {
            case .gold?: .gold
            case .silver?: .silver
            case .bronze?: .bronze
            case .none?, nil: nil
            }
        }

        /// "3 of 6 done", or "Ready!".
        public func caption(_ row: KidRow) -> String {
            guard row.isReady else { return L10n.tr("missions.done_count", row.done, row.total) }
            switch day(of: row.kid.id).medal {
            case .gold: return L10n.tr("missions.ready.gold")
            case .silver: return L10n.tr("missions.ready.silver")
            case .bronze: return L10n.tr("missions.ready.bronze")
            case .none?, nil: return L10n.tr("missions.ready")
            }
        }

        /// The chosen kid's own next outing (for "leave at").
        public var outing: Outing? {
            guard let chosen else { return nil }
            return DayPlanner.nextOuting(in: slots[chosen] ?? [], after: minute)
        }

        /// The family's next outing: the earliest outing today, of any kid, that has not started.
        /// The strip and the header countdown show it whichever kid is chosen (spec "Whose outing").
        public var familyOuting: (kid: Kid, outing: Outing)? {
            kids.compactMap { kid in DayPlanner.nextOuting(in: slots[kid.id] ?? [], after: minute).map { (kid, $0) } }
                .min { $0.1.slot.start < $1.1.slot.start }
        }

        /// Today's latest outing, of any kid, that has already started (user, 2026-11-09): the strip
        /// keeps its road with the mover arrived instead of the empty look.
        public var startedOuting: (kid: Kid, outing: Outing)? {
            kids.flatMap { kid in
                (slots[kid.id] ?? []).compactMap { slot in slot.trip.map { (kid, Outing(slot: slot, trip: $0)) } }
            }
            .filter { $0.1.slot.start <= minute }
            .max { $0.1.slot.start < $1.1.slot.start }
        }

        /// "leave at 7:25 am" under the chosen kid's name.
        /// On the live look it is now + "Leave in" for the kid whose bus it is (spec "Header right").
        public var leaveAt: String? {
            guard let outing else { return nil }
            if let live, familyOuting?.kid.id == chosen {
                // No bus can be caught ("Ask a grown-up"): no leave time to give.
                guard let leaveIn = live.leaveIn else { return nil }
                return L10n.tr("missions.leave_at", TimeText.withPeriod(minute + max(leaveIn, 0)))
            }
            return L10n.tr("missions.leave_at", TimeText.withPeriod(outing.leave))
        }

        /// The mover sits at home 10 minutes before leaving and at the place at the start (clock only).
        public var way: Way? {
            let next = familyOuting
            guard let (owner, outing) = next ?? startedOuting else { return nil }
            // By bus the one bus reaches our stop at "leave"; a car, taxi or walk leaves home at
            // "leave" and reaches 1070 at the start. Once it has started, the mover waits there.
            let moverX = next == nil ? WayStrip.arrivedX
                : outing.trip.way == .bus || outing.trip.way == .shuttle
                ? WayStrip.liveX(minutes: outing.leave - minute)
                : WayStrip.vehicleX(minute: minute, leave: outing.leave, start: outing.slot.start)
            let wayLine = next == nil ? L10n.tr("missions.way.there", outing.slot.title)
                : isBusFallback ? L10n.tr("missions.way.no_live", Self.wayPhrase(.bus))
                : Self.wayLine(outing.trip.way)
            let time = TimeText.withPeriod(outing.slot.start)
            // Only buses and shuttles stop on the way (spec A2-MVP "Way strip").
            let stops = outing.trip.way == .bus || outing.trip.way == .shuttle
            return Way(destination: outing.slot.iconName, mover: outing.trip.way.moverPicture,
                       moverX: moverX,
                       homeLabel: stops ? L10n.tr("missions.our_stop") : L10n.tr("missions.home"),
                       showsStops: stops,
                       cardTitle: L10n.tr("missions.card.title", outing.slot.title, time),
                       cardCaption: wayLine, place: outing.slot.title,
                       owner: owner)
        }

        /// Live times count while the last good answer is under 2 minutes old.
        public static let liveFreshness: TimeInterval = 120

        /// The live look's numbers for the family's bus outing, or nil for the timetable look.
        public var live: LiveMorning? {
            guard let (owner, outing) = familyOuting, outing.trip.way == .bus,
                  let plan = busPlans[owner.id], !plan.routes.isEmpty, let arrivals, let arrivalsAt, let now,
                  now.timeIntervalSince(arrivalsAt) < Self.liveFreshness else { return nil }
            return LiveMorning(arrivals: arrivals, plan: plan, minute: minute, start: outing.slot.start)
        }

        /// The live strip (spec "A2 strip"): every arrival of the kid's buses under 30 min; the chosen
        /// one with the big bubble, every other one faded with its tag (plate + "{n} min").
        public var liveStrip: WayStrip.Live? {
            guard let live, let (owner, outing) = familyOuting else { return nil }
            let plan = busPlans[owner.id]
            let buses = live.buses.enumerated().map { index, bus in
                // User, 2026-11-19: a bus too soon to catch shows its real minutes too.
                let minutes = TimeLeftText.short(minutes: bus.arrival.minutes)
                return WayStrip.LiveBus(id: "\(index)", x: WayStrip.liveX(minutes: bus.arrival.minutes),
                                        picture: Self.busPicture(bus.arrival.type), service: bus.route.service,
                                        minutes: minutes, isMine: bus == live.chosen,
                                        tag: bus == live.chosen ? nil
                                            : .bus(number: bus.route.service, then: bus.route.then, minutes: minutes))
            }
            // Legend: the chosen bus's number, then the kid's other pills faded, in pill order (a bus
            // that changes by its first buses, "12 · 34 → 33").
            let mine = live.chosen?.route ?? plan?.routes.first
            let others = (plan?.pills(besides: mine) ?? []).map {
                WayStrip.Plate($0.buses.joined(separator: strings.tr("bus.join")), then: $0.then)
            }
            // Up to 3, as many as fit the legend's width with the "+{n}" after them.
            let shown = WayStrip.legendCount(others) { strings.tr("missions.legend.more", $0) }
            return WayStrip.Live(buses: buses, destination: KitSlot(iconName: outing.slot.iconName),
                                 destinationLabel: outing.slot.title, ourStopLabel: L10n.tr("missions.our_stop"),
                                 owner: KidFace.Badge(face: owner.face, colorIndex: owner.colorIndex),
                                 myBus: L10n.tr("missions.my_bus"),
                                 myService: mine?.service ?? "", others: Array(others.prefix(shown)),
                                 moreOthers: others.count > shown ? strings.tr("missions.legend.more", others.count - shown) : nil)
        }

        static func busPicture(_ type: BusType) -> KitSlot {
            switch type {
            case .double: .busDouble
            case .single: .busSingle
            case .bendy: .busMini
            }
        }

        /// The timetable look of the strip for the family's outing.
        public var wayTrip: WayStrip.Trip? {
            guard let way else { return nil }
            return WayStrip.Trip(destination: KitSlot(iconName: way.destination), destinationLabel: way.place,
                                 homeLabel: way.homeLabel, showsStops: way.showsStops,
                                 mover: KitSlot(iconName: way.mover), moverX: way.moverX, cardTitle: way.cardTitle,
                                 cardCaption: way.cardCaption,
                                 owner: KidFace.Badge(face: way.owner.face, colorIndex: way.owner.colorIndex))
        }

        /// The family outing goes by bus but there are no fresh live times.
        public var isBusFallback: Bool { familyOuting?.outing.trip.way == .bus && live == nil }

        /// The chosen kid has an outing today: slide to go instead of "All done!".
        /// Every kid slides (user, 2026-11-09): "Ready? Slide to go" with an outing, "All done? Slide!"
        /// without; the slide keeps its done look and undoes by dragging back.
        public var slides: Bool { chosen != nil }

        /// The chosen kid has an outing today (their medal comes from its time).
        public var hasOuting: Bool {
            guard let chosen else { return false }
            return (slots[chosen] ?? []).contains { $0.trip != nil }
        }

        /// Board A3r: the chosen kid's done view in place of the missions (the medal and "Gold!" /
        /// "Ready in good time!", or the prize picture and "Ready!" with no medal).
        public var done: Done? {
            guard let chosen, day(of: chosen).ready else { return nil }
            switch day(of: chosen).medal {
            case .gold?: return Done(medal: .gold, title: L10n.tr("missions.done.gold"),
                                     subtitle: L10n.tr("missions.done.in_time"))
            case .silver?: return Done(medal: .silver, title: L10n.tr("missions.done.silver"),
                                       subtitle: L10n.tr("missions.done.in_time"))
            case .bronze?: return Done(medal: .bronze, title: L10n.tr("missions.done.bronze"),
                                       subtitle: L10n.tr("missions.done.in_time"))
            case .none?, nil:
                // No medal: the prize picture and "Ready!"; a kid with no outing hears "All done for the morning!".
                return Done(medal: nil, title: L10n.tr("missions.ready"),
                            subtitle: hasOuting ? nil : L10n.tr("missions.done.all_done"))
            }
        }

        /// The chosen kid is ready (the slide shows its done look, "Ready!").
        public var chosenIsReady: Bool { chosen.map { day(of: $0).ready } ?? false }

        /// "Ready, Kid A!" once the chosen kid is ready; else "Good morning!".
        public var title: String {
            guard let kid = chosenKid, day(of: kid.id).ready else {
                // Board A2t-w: on the weekend the greeting names the day.
                if let weekday, weekday == .saturday || weekday == .sunday {
                    return L10n.tr("missions.title.weekend", DayText.name(weekday))
                }
                return L10n.tr("missions.title")
            }
            return L10n.tr("missions.ready_title", kid.name)
        }

        /// Header right: "Leave in" with the status on the live look and the bus fallback,
        /// "{Place} in" otherwise.
        public var header: Header? {
            guard let (_, outing) = familyOuting else { return nil }
            if let live {
                return Header(label: live.leaveIn == nil ? nil : L10n.tr("missions.leave_in"),
                              minutes: live.leaveIn.map { TimeLeftText.short(minutes: max($0, 0)) } ?? "",
                              status: live.status.map(Self.statusLine))
            }
            // The timetable look counts to "leave" (start − leave before) with no status.
            return Header(label: L10n.tr("missions.leave_in"),
                          minutes: TimeLeftText.short(minutes: max(outing.leave - minute, 0)), status: nil)
        }

        static func statusLine(_ status: LiveMorning.Status) -> StatusLine {
            switch status {
            case .onTime: StatusLine(text: L10n.tr("missions.status.on_time"), tone: .onTime)
            case .leaveNow: StatusLine(text: L10n.tr("missions.status.leave_now"), tone: .hurry)
            case .askGrownup: StatusLine(text: L10n.tr("missions.status.ask"), tone: .quiet)
            }
        }

        /// "by bus", "on foot".
        static func wayPhrase(_ way: Domain.Way) -> String {
            switch way {
            case .walk: L10n.tr("way.on_foot")
            case .bus: L10n.tr("way.by_bus")
            case .car: L10n.tr("way.by_car")
            case .taxi: L10n.tr("way.by_taxi")
            case .shuttle: L10n.tr("way.by_shuttle")
            }
        }

        /// The way card's caption: only the bus and the shuttle run on a timetable.
        static func wayLine(_ way: Domain.Way) -> String {
            switch way {
            case .bus, .shuttle: L10n.tr("missions.way.timetable", wayPhrase(way))
            case .walk, .car, .taxi: wayPhrase(way)
            }
        }

        /// 6 circles a kid with two kids or more, 8 with one (spec A2m).
        public var capacity: Int { kids.count > 1 ? 6 : 8 }

        /// The chosen kid's row: every mission when they fit; else the done ones fold into one ✓ at the
        /// start, and if still too many, the last place is "+n" for the next page, or "‹" back on the
        /// last page.
        public var circles: [Circle] {
            guard let chosen else { return [] }
            let list = list(of: chosen), done = day(of: chosen).done
            let current = list.first { !done.contains($0.id) }?.id
            func circle(_ mission: WindowMission) -> Circle {
                .mission(mission, isDone: done.contains(mission.id), isCurrent: mission.id == current)
            }
            if list.count <= capacity { return list.map(circle) }
            let doneCount = list.filter { done.contains($0.id) }.count
            let open = list.filter { !done.contains($0.id) }
            var head: [Circle] = doneCount > 0 ? [.folded(count: doneCount)] : []
            let room = capacity - head.count
            if open.count <= room { return head + open.map(circle) }
            let perPage = room - 1
            let pages = (open.count + perPage - 1) / perPage
            let start = (page % pages) * perPage
            let shown = open.dropFirst(start).prefix(perPage)
            head += shown.map(circle)
            let after = open.count - start - shown.count
            return head + [after > 0 ? .more(count: after) : .back]
        }

        public var everyoneReady: Bool { !kids.isEmpty && kids.allSatisfy { day(of: $0.id).ready } }

        /// "Ready? Slide to go" for a kid with an outing, "All done? Slide!" otherwise (board A3).
        public var slideTitle: String {
            hasOuting ? L10n.tr("missions.slide") : L10n.tr("missions.slide.all_done")
        }

        /// The done knob for a kid ready without a medal: the crown in place of the knob and its check.
        public var slideDoneKnob: KitSlot? {
            guard let chosen, day(of: chosen).ready, Self.medalKind(day(of: chosen).medal) == nil else { return nil }
            return .crown
        }

        /// The knob: the way picture for a kid with an outing, the star sticker otherwise.
        public var slideKnob: KitSlot {
            guard let chosen, let trip = (slots[chosen] ?? []).first(where: { $0.trip != nil })?.trip else { return .star }
            return KitSlot(iconName: trip.way.moverPicture)
        }

        /// The picture plays its rig once each time a mission is tapped (spec, with the check).
        public var plays: [Mission.ID: Int] = [:]

        // MARK: What the view shows (it holds no values of its own)

        /// The strip's words on a day without an outing.
        public var homeAllDayText: String { strings.tr("missions.home_all_day") }
        /// The slide's title once the chosen kid is ready.
        public var slideDoneTitle: String { strings.tr("missions.ready") }
        /// The slide rests done once the chosen kid is ready, idle otherwise.
        public var slidePhase: SlideToGoModel.Phase { chosenIsReady ? .done : .idle }

        /// The name under a circle: the mission's, or the folded, more and back circles' words.
        public func name(of circle: Circle) -> String {
            switch circle {
            case let .mission(mission, _, _): mission.name
            case let .folded(count): strings.tr("missions.folded", count)
            case let .more(count): strings.tr("missions.more", count)
            case .back: strings.tr("missions.page_back")
            }
        }

        /// "+3" inside the more circle.
        public func moreText(count: Int) -> String { strings.tr("missions.more_count", count) }

        /// A mission's picture (an unknown name shows play).
        public func picture(of mission: WindowMission) -> KitSlot { KitSlot(iconName: mission.picture) }

        /// A mission picture's play id: it plays its rig each time this goes up.
        public func playID(of mission: Mission.ID) -> Int { plays[mission, default: 0] }
        /// Crayon confetti plays once per slide (board 0g2).
        public var confetti = 0
    }

    public enum Action: Equatable {
        case task
        case tick(Date)
        case loaded(ScheduleSnapshot?, family: FamilyCalendar, marks: [WindowMissions], slides: [OutingSlide])
        case kidTapped(Kid.ID)
        case missionTapped(Mission.ID)
        case moreTapped
        case backPageTapped
        case slid
        /// The done slide was dragged back past the middle: not ready any more, the medal goes.
        case slideUndone
        case refresh
        case arrivalsLoaded([BusArrival]?, at: Date)
        case backTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// Back to the clock.
            case finished
        }
    }

    @Dependency(\.scheduleStore) var scheduleStore
    @Dependency(\.holidays) var holidays
    @Dependency(\.schoolDirectory) var schoolDirectory
    @Dependency(\.appSettings) var appSettings
    @Dependency(\.bus) var bus
    @Dependency(\.calendar) var calendar
    @Dependency(\.date) var date
    @Dependency(\.continuousClock) var clock

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let now = date.now
                let today = Day(now, calendar: calendar)
                state.today = today
                state.weekday = today.weekday(calendar)
                state.minute = Day.minute(of: now, calendar: calendar)
                state.now = now
                return .merge(
                    .run { [scheduleStore, holidays, schoolDirectory, calendar, minute = state.minute,
                            opened = state.opened, weekday = state.weekday ?? .monday] send in
                        let snapshot = try? await scheduleStore.load()
                        let family = await schoolDirectory.family(
                            kids: snapshot?.kids ?? [], publicHolidays: await holidays.holidays(today.year).map(\.day))
                        let lists = snapshot.map {
                            State.listSlots(Self.slots($0, today: today, family: family, calendar: calendar),
                                            bundles: $0.bundles, weekday: weekday, minute: minute, opened: opened)
                        } ?? [:]
                        var marks: [WindowMissions] = []
                        var slides: [OutingSlide] = []
                        for kid in snapshot?.kids ?? [] {
                            // The list's own record, and today's old morning record (moved once below).
                            let daySlots = snapshot.map { Self.slots($0, today: today, family: family, calendar: calendar)[kid.id] ?? [] } ?? []
                            let parts = (lists[kid.id].map { [MissionWindow.before(ListRef($0, in: daySlots))] } ?? []) + [.morning]
                            for part in parts {
                                if let window = try? await scheduleStore.windowMissions(kid.id, today, part) {
                                    marks.append(window)
                                }
                            }
                            slides += (try? await scheduleStore.slides(kid.id, today)) ?? []
                        }
                        await send(.loaded(snapshot, family: family, marks: marks, slides: slides))
                    },
                    // The mover moves by the clock: a new minute redraws it.
                    .run { [clock, date] send in
                        for await _ in clock.timer(interval: .seconds(15)) { await send(.tick(date.now)) }
                    }
                )

            case let .tick(now):
                state.minute = Day.minute(of: now, calendar: calendar)
                state.now = now
                return .none

            case .refresh:
                // S4 "Live bus times" off: no LTA call; the morning keeps the timetable look.
                guard let (owner, outing) = state.familyOuting,
                      outing.trip.way == .bus, let plan = state.busPlans[owner.id], !plan.routes.isEmpty else { return .none }
                return .run { [bus, date] send in
                    let arrivals = try? await bus.arrivals(plan.stop)
                    await send(.arrivalsLoaded(arrivals, at: date.now))
                }

            case let .arrivalsLoaded(arrivals, at):
                // A failed call keeps the last good answer until it is too old (spec "Refresh").
                guard let arrivals else { return .none }
                state.arrivals = arrivals
                state.arrivalsAt = at
                state.now = at
                return .none

            case let .loaded(snapshot, family, marks, slides):
                guard let snapshot, let today = state.today else { return .none }
                state.kids = snapshot.kids
                state.missions = snapshot.missions
                state.items = family.resolving(snapshot.items, calendar: calendar)
                state.slots = Self.slots(snapshot, today: today, family: family, calendar: calendar)
                state.bundles = snapshot.bundles
                state.listSlots = State.listSlots(state.slots, bundles: snapshot.bundles, weekday: state.weekday ?? .monday,
                                                  minute: state.minute, opened: state.opened)
                state.spans = Dictionary(uniqueKeysWithValues: state.listSlots.map { kid, slot in
                    (kid, State.span(for: slot, in: state.slots[kid] ?? []))
                })
                // Opened from a row: only that event's kids (spec A2 "the kid column").
                if state.opened != nil { state.kids = snapshot.kids.filter { state.listSlots[$0.id] != nil } }
                // Issue 024: today's done marks from the old morning window move once to the kid's first
                // list of the day, when that list has none yet; the morning record is then emptied.
                var moved: [Kid.ID] = []
                state.days = Dictionary(uniqueKeysWithValues: snapshot.kids.map { kid in
                    let parts = state.spans[kid.id]?.parts ?? []
                    var done = marks.filter { $0.kid == kid.id && parts.contains($0.window) }
                        .reduce(into: Set<Mission.ID>()) { $0.formUnion($1.done) }
                    let morning = marks.first { $0.kid == kid.id && $0.window == .morning }?.done ?? []
                    let first = State.listEvents(kid: kid.id, slots: state.slots[kid.id] ?? [], bundles: snapshot.bundles,
                                                 weekday: state.weekday ?? .monday).first
                    if done.isEmpty, !morning.isEmpty, let slot = state.listSlots[kid.id], slot == first {
                        done = morning
                        moved.append(kid.id)
                    }
                    let outing = state.outingEvent(of: kid.id)
                    let slide = slides.first { $0.kid == kid.id && $0.outing == outing }
                    return (kid.id, MissionDay(kid: kid.id, date: today, done: done, ready: slide?.ready ?? false,
                                               readyAt: slide?.readyAt, medal: slide?.medal))
                })
                // The kids' School routes (the morning screen follows School); the kid's school late
                // grace wins over the plan's (spec "Latest lives on the school record").
                state.busPlans = Dictionary(snapshot.kids.compactMap { kid in
                    snapshot.busPlans.route(kid: kid.id).map { (kid.id, $0.graced(by: kid)) }
                }, uniquingKeysWith: { $1 })
                // Home's mission row opens A2 on its kid (spec A1 "Mission rows"); else the next kid.
                state.chosen = state.chosen.flatMap { id in state.kids.contains { $0.id == id } ? id : nil }
                    ?? nextKid(in: state)
                state.page = 0
                // The list's record first; the morning record is emptied only once that save worked, so a
                // failed save keeps the old marks to move next time and a later untick sticks.
                let migrations = moved.map { kid -> Effect<Action> in
                    let day = state.day(of: kid)
                    let marks = listMarks(day, in: state)
                    return .run { [scheduleStore] _ in
                        do {
                            for window in marks { try await scheduleStore.saveWindowMissions(window) }
                            try await scheduleStore.saveWindowMissions(WindowMissions(kid: kid, date: day.date, window: .morning))
                        } catch {}
                    }
                }
                // Live times on open and every 30 s while the screen is open; nothing in the background.
                return .merge(migrations + [.run { [clock] send in
                    await send(.refresh)
                    for await _ in clock.timer(interval: .seconds(30)) { await send(.refresh) }
                }
                .cancellable(id: CancelID.refresh, cancelInFlight: true)])

            case let .kidTapped(kid):
                // Tapping a ready kid's row shows their done view again (undo is on the slide).
                state.chosen = kid
                state.page = 0
                return .none

            case .slid:
                guard let kid = state.chosen else { return .none }
                var day = state.day(of: kid)
                day.ready = true
                day.readyAt = state.minute
                day.medal = medal(for: kid, in: state)
                state.days[kid] = day
                state.confetti += 1
                // Board A3: the kid stays chosen with their done view; nothing switches kids by
                // itself, only a row tap does.
                return save(day, in: state)

            case .slideUndone:
                guard let kid = state.chosen else { return .none }
                var day = state.day(of: kid)
                day.ready = false
                day.readyAt = nil
                day.medal = nil
                state.days[kid] = day
                return save(day, in: state)

            case let .missionTapped(id):
                guard let kid = state.chosen else { return .none }
                var day = state.day(of: kid)
                if day.done.contains(id) { day.done.remove(id) } else { day.done.insert(id) }
                state.days[kid] = day
                state.plays[id, default: 0] += 1
                return save(day, in: state)

            case .moreTapped:
                state.page += 1
                return .none

            case .backPageTapped:
                state.page = 0
                return .none

            case .backTapped:
                return .merge(.cancel(id: CancelID.refresh), .send(.delegate(.finished)))

            case .delegate:
                return .none
            }
        }
    }

    /// The kid to show first or next: not ready yet, the one leaving earliest; else the first kid.
    private func nextKid(in state: State) -> Kid.ID? {
        let open = state.kids.filter { !state.day(of: $0.id).ready }
        let leaving = open.min { a, b in
            let la = DayPlanner.nextOuting(in: state.slots[a.id] ?? [], after: state.minute)?.leave ?? .max
            let lb = DayPlanner.nextOuting(in: state.slots[b.id] ?? [], after: state.minute)?.leave ?? .max
            return la < lb
        }
        return (leaving ?? state.kids.first)?.id
    }

    private enum CancelID { case refresh }

    /// Spec "Medal from the time only": from the live arrivals when the kid's own outing is the
    /// live one, else from the timetable.
    private func medal(for kid: Kid.ID, in state: State) -> MorningMedal {
        // S4 "Medals" off: no medal anywhere; the slide still ends on "Ready!".
        guard appSettings.load().medals else { return .none }
        guard let outing = DayPlanner.nextOuting(in: state.slots[kid] ?? [], after: state.minute)
                ?? (state.slots[kid] ?? []).first(where: { $0.trip != nil }).flatMap({ slot in
                    slot.trip.map { Outing(slot: slot, trip: $0) } })
        else { return .none }
        // Spec S1–S4: a preschool trip earns no medal.
        let isSchool = outing.slot.kind == .school
        if isSchool, state.kids.first(where: { $0.id == kid })?.school?.isPreschool == true {
            return .none
        }
        // Spec "Events: one shape", Medal: on by default for School, off for other events.
        guard outing.trip.givesMedal(isSchool: isSchool) else { return .none }
        let plan = isSchool ? state.busPlans[kid] : nil
        let grace = isSchool
            ? state.kids.first { $0.id == kid }?.school?.lateGrace ?? plan?.lateGrace ?? BusPlan.defaultLateGrace
            : outing.trip.lateGrace ?? BusPlan.defaultLateGrace
        if outing.trip.way == .bus, state.live != nil, let plan, let arrivals = state.arrivals,
           let targets = LiveMorning.leaveTargets(arrivals: arrivals, plan: plan, minute: state.minute,
                                                  start: outing.slot.start) {
            return LiveMorning.medal(readyAt: state.minute, ideal: targets.ideal, latest: targets.latest)
        }
        let targets = LiveMorning.timetableTargets(start: outing.slot.start, leaveBefore: outing.trip.leaveBefore,
                                                   lateGrace: grace)
        return LiveMorning.medal(readyAt: state.minute, ideal: targets.ideal, latest: targets.latest)
    }

    /// Splits the screen's day into its records: each window part's done missions, and the slide of
    /// the outing the window leads to (the window's own slide when it leads to none).
    private func save(_ day: MissionDay, in state: State) -> Effect<Action> {
        let marks = listMarks(day, in: state)
        let slide = OutingSlide(kid: day.kid, date: day.date, outing: state.outingEvent(of: day.kid), ready: day.ready,
                                readyAt: day.readyAt, medal: day.medal)
        return .run { [scheduleStore] _ in
            for window in marks { try? await scheduleStore.saveWindowMissions(window) }
            try? await scheduleStore.saveSlide(slide)
        }
    }

    /// The kid's list record with the day's done missions in it.
    private func listMarks(_ day: MissionDay, in state: State) -> [WindowMissions] {
        let list = state.list(of: day.kid)
        return (state.spans[day.kid]?.parts ?? []).map { part in
            WindowMissions(kid: day.kid, date: day.date, window: part,
                           done: Set(list.filter { $0.window == part && day.done.contains($0.id) }.map(\.id)))
        }
    }

    /// Every kid's slots today.
    static func slots(_ snapshot: ScheduleSnapshot, today: Day, family: FamilyCalendar,
                      calendar: Calendar) -> [Kid.ID: [Slot]] {
        Dictionary(uniqueKeysWithValues: snapshot.kids.map { kid in
            (kid.id, DayPlanner.slots(on: today, kid: kid, routines: kid.readingWaitingHours(snapshot.routines), items: family.resolving(snapshot.items, calendar: calendar),
                                      holidays: family.daysOff(kid.id), calendar: calendar))
        })
    }

    /// Every kid's night (wake-up and evening) from today's template.
    static func nights(_ snapshot: ScheduleSnapshot, today: Day, family: FamilyCalendar,
                       calendar: Calendar) -> [Kid.ID: NightSpan?] {
        Dictionary(uniqueKeysWithValues: snapshot.kids.map { kid in
            (kid.id, DayPlanner.nightSpan(of: DayPlanner.template(for: kid.id, on: today, routines: kid.readingWaitingHours(snapshot.routines),
                                                                  holidays: family.daysOff(kid.id), calendar: calendar)))
        })
    }
}
