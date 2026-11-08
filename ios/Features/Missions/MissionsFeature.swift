import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import HolidayProvider
import ScheduleStore
import Strings

/// A2-MVP · Morning missions (spec "A2-MVP", "MVP data"): the way to the chosen kid's next outing,
/// the kid list, the chosen kid's mission circles and "All done!". Kids are never locked: missions
/// only help, "All done!" is always on.
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

    public struct KidRow: Equatable, Sendable, Identifiable {
        public var kid: Kid
        public var done: Int
        public var total: Int
        public var isReady: Bool
        public var id: Kid.ID { kid.id }
        public var progress: Double { isReady ? 1 : total == 0 ? 0 : Double(done) / Double(total) }
    }

    /// The way strip's content for the chosen kid's next outing.
    public struct Way: Equatable, Sendable {
        public var destination: String
        public var mover: String
        public var progress: Double
        public var homeLabel: String
        public var showsStops: Bool
        public var cardTitle: String
        public var cardCaption: String
        public var headerPlace: String
        public var headerMinutes: String
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
                              isReady: day.ready)
            }
        }

        /// "3 of 6 done", or "Ready!".
        public func caption(_ row: KidRow) -> String {
            row.isReady ? L10n.tr("missions.ready") : L10n.tr("missions.done_count", row.done, row.total)
        }

        public var outing: Outing? {
            guard let chosen else { return nil }
            return DayPlanner.nextOuting(in: slots[chosen] ?? [], after: minute)
        }

        /// "leave at 7:25 am" under the chosen kid's name.
        public var leaveAt: String? { outing.map { L10n.tr("missions.leave_at", TimeText.withPeriod($0.leave)) } }

        /// The mover sits at home 10 minutes before leaving and at the place at the start (clock only).
        public var way: Way? {
            guard let outing else { return nil }
            let from = outing.leave - 10, to = outing.slot.start
            let progress = to > from ? Double(minute - from) / Double(to - from) : 1
            let wayLine = Self.wayLine(outing.trip.way)
            let time = TimeText.withPeriod(outing.slot.start)
            let minutes = TimeLeft.presentation(minutes: max(outing.slot.start - minute, 0)).text
            return Way(destination: outing.slot.iconName, mover: outing.trip.way.moverPicture,
                       progress: min(max(progress, 0), 1),
                       homeLabel: outing.trip.way == .bus ? L10n.tr("missions.our_stop") : L10n.tr("missions.home"),
                       showsStops: outing.trip.way == .bus,
                       cardTitle: L10n.tr("missions.card.title", outing.slot.title, time),
                       cardCaption: wayLine,
                       headerPlace: L10n.tr("home.place_in", outing.slot.title), headerMinutes: minutes,
                       spoken: L10n.tr("missions.way.spoken", outing.slot.title, Self.wayPhrase(outing.trip.way), minutes,
                                       outing.slot.title, time))
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

        /// "All done!", or "Back to the clock" once every kid is ready.
        public var buttonTitle: String {
            everyoneReady ? L10n.tr("missions.back") : L10n.tr("missions.all_done")
        }
    }

    public enum Action: Equatable {
        case task
        case tick(Date)
        case loaded(ScheduleSnapshot?, holidays: [Holiday], days: [MissionDay])
        case kidTapped(Kid.ID)
        case missionTapped(Mission.ID)
        case moreTapped
        case backPageTapped
        case allDoneTapped
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
                state.chosen = nextKid(in: state)
                state.page = 0
                return .none

            case let .kidTapped(kid):
                state.chosen = kid
                state.page = 0
                return .none

            case let .missionTapped(id):
                guard let kid = state.chosen else { return .none }
                var day = state.day(of: kid)
                if day.done.contains(id) { day.done.remove(id) } else { day.done.insert(id) }
                state.days[kid] = day
                return save(day)

            case .moreTapped:
                state.page += 1
                return .none

            case .backPageTapped:
                state.page = 0
                return .none

            case .allDoneTapped:
                if state.everyoneReady { return .send(.delegate(.finished)) }
                guard let kid = state.chosen else { return .none }
                var day = state.day(of: kid)
                day.ready = true
                state.days[kid] = day
                state.chosen = nextKid(in: state) ?? kid
                state.page = 0
                return save(day)

            case .backTapped:
                return .send(.delegate(.finished))

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

    private func save(_ day: MissionDay) -> Effect<Action> {
        .run { [scheduleStore] _ in try? await scheduleStore.saveMissionDay(day) }
    }
}
