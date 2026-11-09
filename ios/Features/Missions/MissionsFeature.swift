import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import BusClient
import HolidayProvider
import KitArt
import ScheduleStore
import Strings

/// A2-MVP · Morning missions (spec "A2-MVP", "MVP data"): the way to the chosen kid's next outing,
/// the kid list, the chosen kid's mission circles and the slide. Kids are never locked: missions
/// only help, the slide is always on.
@Reducer
public struct MissionsFeature {
    /// One place in the mission row: a mission, the done ones folded into one ✓, or "+n" for the next page.
    public enum Circle: Equatable, Sendable, Identifiable {
        case mission(Mission, isDone: Bool, isCurrent: Bool)
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
        public var spoken: String
    }

    @ObservableState
    public struct State: Equatable {
        public var today: Day?
        public var minute = 0
        public var kids: [Kid] = []
        public var missions: [Mission] = []
        public var slots: [Kid.ID: [Slot]] = [:]
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

        public init() {}

        public var chosenKid: Kid? { kids.first { $0.id == chosen } }

        public func missions(of kid: Kid.ID) -> [Mission] {
            missions.filter { $0.kid == kid }.sorted { $0.order < $1.order }
        }

        public func day(of kid: Kid.ID) -> MissionDay {
            days[kid] ?? MissionDay(kid: kid, date: today ?? Day(year: 2000, month: 1, day: 1))
        }

        public var rows: [KidRow] {
            kids.map { kid in
                let list = missions(of: kid.id), day = day(of: kid.id)
                return KidRow(kid: kid, done: list.filter { day.done.contains($0.id) }.count, total: list.count,
                              isReady: day.ready, medal: day.ready ? Self.medalKind(day.medal) : nil)
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
                       owner: owner,
                       spoken: L10n.tr("missions.way.spoken", owner.name, outing.slot.title,
                                       Self.wayPhrase(outing.trip.way),
                                       TimeLeft.spoken(minutes: max(outing.slot.start - minute, 0)), outing.slot.title, time))
        }

        /// Live times count while the last good answer is under 2 minutes old.
        public static let liveFreshness: TimeInterval = 120

        /// The live look's numbers for the family's bus outing, or nil for the timetable look.
        public var live: LiveMorning? {
            guard let (owner, outing) = familyOuting, outing.trip.way == .bus,
                  let plan = busPlans[owner.id], let arrivals, let arrivalsAt, let now,
                  now.timeIntervalSince(arrivalsAt) < Self.liveFreshness else { return nil }
            return LiveMorning(arrivals: arrivals, plan: plan, minute: minute, start: outing.slot.start)
        }

        /// The live strip (spec "A2 live look"): the next two arrivals, plus the kid's bus when it is
        /// later; bubbles over the kid's bus and an earlier "too soon" one unless they would overlap.
        public var liveStrip: WayStrip.Live? {
            guard let live, let (owner, outing) = familyOuting else { return nil }
            var arrivals = live.shown
            if let chosen = live.chosen, !arrivals.contains(chosen) { arrivals.append(chosen) }
            let mineX = live.chosen.map { WayStrip.liveX(minutes: $0.minutes) }
            let buses = arrivals.enumerated().map { index, arrival in
                let isMine = arrival == live.chosen, isTooSoon = arrival == live.tooSoon
                let x = WayStrip.liveX(minutes: arrival.minutes)
                let clear = mineX.map { abs($0 - x) >= 220 } ?? true
                return WayStrip.LiveBus(id: "\(index)", x: x, picture: Self.busPicture(arrival.type),
                                        service: arrival.service,
                                        minutes: TimeLeft.presentation(minutes: arrival.minutes).text,
                                        isMine: isMine, isTooSoon: isTooSoon && !isMine,
                                        showsBubble: isMine || (isTooSoon && clear))
            }
            return WayStrip.Live(buses: buses, destination: KitSlot(iconName: outing.slot.iconName),
                                 destinationLabel: outing.slot.title, ourStopLabel: L10n.tr("missions.our_stop"),
                                 owner: KidFace.Badge(face: owner.face, colorIndex: owner.colorIndex),
                                 ownerName: owner.name, myBus: L10n.tr("missions.my_bus"),
                                 tooSoon: L10n.tr("missions.too_soon"),
                                 myService: live.chosen?.service ?? busPlans[owner.id]?.services.first ?? "")
        }

        /// "Live bus map. Bus 1 in 28 minutes, your bus. Leave in 18 minutes, on time."
        public var liveSpoken: String? {
            guard let live, let chosen = live.chosen, let leaveIn = live.leaveIn else { return nil }
            return L10n.tr("missions.live.spoken", chosen.service, TimeLeft.spoken(minutes: chosen.minutes),
                           TimeLeft.spoken(minutes: max(leaveIn, 0)), live.status.map { Self.statusLine($0).text } ?? "")
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
                                 owner: KidFace.Badge(face: way.owner.face, colorIndex: way.owner.colorIndex),
                                 ownerName: way.owner.name)
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
            guard let kid = chosenKid, day(of: kid.id).ready else { return L10n.tr("missions.title") }
            return L10n.tr("missions.ready_title", kid.name)
        }

        /// Header right: "Leave in" with the status on the live look and the bus fallback,
        /// "{Place} in" otherwise.
        public var header: Header? {
            guard let (_, outing) = familyOuting else { return nil }
            if let live {
                return Header(label: live.leaveIn == nil ? nil : L10n.tr("missions.leave_in"),
                              minutes: live.leaveIn.map { TimeLeft.presentation(minutes: max($0, 0)).text } ?? "",
                              status: live.status.map(Self.statusLine))
            }
            // The timetable look counts to "leave" (start − leave before) with no status.
            return Header(label: L10n.tr("missions.leave_in"),
                          minutes: TimeLeft.presentation(minutes: max(outing.leave - minute, 0)).text, status: nil)
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
            let list = missions(of: chosen), done = day(of: chosen).done
            let current = list.first { !done.contains($0.id) }?.id
            func circle(_ mission: Mission) -> Circle {
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
            guard let chosen, day(of: chosen).ready, day(of: chosen).medal == nil else { return nil }
            return .crown
        }

        /// The knob: the way picture for a kid with an outing, the star sticker otherwise.
        public var slideKnob: KitSlot {
            guard let chosen, let trip = (slots[chosen] ?? []).first(where: { $0.trip != nil })?.trip else { return .star }
            return KitSlot(iconName: trip.way.moverPicture)
        }

        /// The picture plays its rig once each time a mission is tapped (spec, with the check).
        public var plays: [Mission.ID: Int] = [:]
        /// Crayon confetti plays once per slide (board 0g2).
        public var confetti = 0
    }

    public enum Action: Equatable {
        case task
        case tick(Date)
        case loaded(ScheduleSnapshot?, holidays: [Holiday], days: [MissionDay])
        case kidTapped(Kid.ID)
        case missionTapped(Mission.ID)
        case moreTapped
        case backPageTapped
        case slid
        /// The done slide was dragged back past the middle: not ready any more, the medal goes.
        case slideUndone
        /// 3 s after a slide: on to the next unfinished kid (board A3).
        case readyShown
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
                state.minute = Day.minute(of: now, calendar: calendar)
                state.now = now
                return .merge(
                    .run { [scheduleStore, holidays] send in
                        let snapshot = try? await scheduleStore.load()
                        var days: [MissionDay] = []
                        for kid in snapshot?.kids ?? [] {
                            if let day = try? await scheduleStore.missionDay(kid.id, today) { days.append(day) }
                        }
                        await send(.loaded(snapshot, holidays: await holidays.holidays(today.year), days: days))
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
                guard let (owner, outing) = state.familyOuting, outing.trip.way == .bus,
                      let plan = state.busPlans[owner.id] else { return .none }
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

            case let .loaded(snapshot, holidays, days):
                guard let snapshot, let today = state.today else { return .none }
                let holidayDays = Set(holidays.map(\.day))
                state.kids = snapshot.kids
                state.missions = snapshot.missions
                state.slots = Dictionary(uniqueKeysWithValues: snapshot.kids.map { kid in
                    (kid.id, DayPlanner.slots(on: today, kid: kid, routines: snapshot.routines, items: snapshot.items,
                                              holidays: holidayDays, calendar: calendar))
                })
                state.days = Dictionary(uniqueKeysWithValues: days.map { ($0.kid, $0) })
                // The kid's school late grace wins over the plan's (spec "Latest lives on the school record").
                state.busPlans = Dictionary(snapshot.busPlans.map { plan in
                    (plan.kid, plan.graced(by: snapshot.kids.first { $0.id == plan.kid }))
                }, uniquingKeysWith: { $1 })
                state.chosen = nextKid(in: state)
                state.page = 0
                // Live times on open and every 30 s while the screen is open; nothing in the background.
                return .run { [clock] send in
                    await send(.refresh)
                    for await _ in clock.timer(interval: .seconds(30)) { await send(.refresh) }
                }
                .cancellable(id: CancelID.refresh, cancelInFlight: true)

            case let .kidTapped(kid):
                // Tapping a ready kid's row shows their done view again (undo is on the slide).
                state.chosen = kid
                state.page = 0
                return .cancel(id: CancelID.advance)

            case .slid:
                guard let kid = state.chosen else { return .none }
                var day = state.day(of: kid)
                day.ready = true
                day.readyAt = state.minute
                day.medal = medal(for: kid, in: state)
                state.days[kid] = day
                state.confetti += 1
                // The kid stays chosen and sees their done view; 3 s later the next kid comes up.
                return .merge(save(day), .run { [clock] send in
                    try await clock.sleep(for: .seconds(3))
                    await send(.readyShown)
                }
                .cancellable(id: CancelID.advance, cancelInFlight: true))

            case .slideUndone:
                guard let kid = state.chosen else { return .none }
                var day = state.day(of: kid)
                day.ready = false
                day.readyAt = nil
                day.medal = nil
                state.days[kid] = day
                return .merge(.cancel(id: CancelID.advance), save(day))

            case .readyShown:
                state.chosen = nextKid(in: state) ?? state.chosen
                state.page = 0
                return .none

            case let .missionTapped(id):
                guard let kid = state.chosen else { return .none }
                var day = state.day(of: kid)
                if day.done.contains(id) { day.done.remove(id) } else { day.done.insert(id) }
                state.days[kid] = day
                state.plays[id, default: 0] += 1
                return save(day)

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

    private enum CancelID { case refresh, advance }

    /// Spec "Medal from the time only": from the live arrivals when the kid's own outing is the
    /// live one, else from the timetable.
    private func medal(for kid: Kid.ID, in state: State) -> MorningMedal {
        guard let outing = DayPlanner.nextOuting(in: state.slots[kid] ?? [], after: state.minute)
                ?? (state.slots[kid] ?? []).first(where: { $0.trip != nil }).flatMap({ slot in
                    slot.trip.map { Outing(slot: slot, trip: $0) } })
        else { return .none }
        // Spec S1–S4: a preschool trip earns no medal.
        if outing.slot.kind == .school, state.kids.first(where: { $0.id == kid })?.school?.isPreschool == true {
            return .none
        }
        let plan = state.busPlans[kid]
        let grace = state.kids.first { $0.id == kid }?.school?.lateGrace ?? plan?.lateGrace ?? BusPlan.defaultLateGrace
        if outing.trip.way == .bus, state.live != nil, let plan, let arrivals = state.arrivals,
           let targets = LiveMorning.leaveTargets(arrivals: arrivals, plan: plan, minute: state.minute,
                                                  start: outing.slot.start) {
            return LiveMorning.medal(readyAt: state.minute, ideal: targets.ideal, latest: targets.latest)
        }
        let targets = LiveMorning.timetableTargets(start: outing.slot.start, leaveBefore: outing.trip.leaveBefore,
                                                   lateGrace: grace)
        return LiveMorning.medal(readyAt: state.minute, ideal: targets.ideal, latest: targets.latest)
    }

    private func save(_ day: MissionDay) -> Effect<Action> {
        .run { [scheduleStore] _ in try? await scheduleStore.saveMissionDay(day) }
    }
}
