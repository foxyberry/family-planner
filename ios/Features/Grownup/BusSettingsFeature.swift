import BusClient
import ComposableArchitecture
import Domain
import Foundation
import Localization
import ScheduleStore
import Strings

/// C2 · Our buses (spec "Bus settings", first cut): plan A only. The stop code with its name as a
/// check, the kid's bus numbers as chips from what calls at the stop, and walk / ride / late grace.
/// Live times use the key built into the app; stop codes and numbers never leave the iPad.
@Reducer
public struct BusSettingsFeature {
    @ObservableState
    public struct State: Equatable {
        public var strings = Localizer.injected
        public var kid: Kid.ID
        public var kidName = ""
        /// The stop field (shared with S3).
        public var search = StopSearchFeature.State()
        /// The kid's buses, all equal (spec "Several buses"), in pill order.
        public var services: [String] = []
        public var walk = BusPlan.defaultWalk
        /// The ride a newly picked bus starts with.
        public var ride = BusPlan.defaultRide
        public var lateGrace = BusPlan.defaultLateGrace
        /// Each picked bus's own ride.
        public var rides: [String: Int] = [:]
        /// The buses that change (C2c), each one more equal pill.
        public var changes: [BusChange] = []
        /// The kid as stored: "Late" is their school's Latest − Arrive by when the school has both
        /// (spec "Latest lives on the school record"), else the plan's own value.
        public var storedKid: Kid?
        /// The route has been read once this visit. C2 keeps it in memory from then on, so coming
        /// back from C2c never reads an older copy over what C2c just handed back.
        public var isLoaded = false

        public init(kid: Kid.ID) {
            self.kid = kid
        }

        public var title: String { strings.tr("c2.title") }
        public var stopLabel: String { strings.tr("c2.stop") }
        public var busesLabel: String { strings.tr("c2.buses") }
        public var noBusesText: String { strings.tr("c2.buses.none") }
        public var walkLabel: String { strings.tr("c2.walk") }
        public var walkCaption: String { strings.tr("c2.walk.caption") }
        public var graceLabel: String { strings.tr("c2.grace") }
        public var graceCaption: String { strings.tr("c2.grace.caption") }
        public var doneTitle: String { strings.tr("c2.done") }
        public var walkText: String { strings.tr("c2.minutes", walk) }
        public var graceText: String { strings.tr("c2.minutes", lateGrace) }
        /// Which of the Walk and Late grace −/+ can still be pressed.
        public var walkEnds: StepEnds { StepRange.walk.ends(walk) }
        public var graceEnds: StepEnds { StepRange.lateGrace.ends(lateGrace) }

        /// One Ride row per picked bus, in pill order ("on 12"); the label "Ride" on the first only.
        /// With no bus picked, one Ride row ("stop to school") sets the ride a new pick starts with.
        public struct RideRow: Equatable, Identifiable, Sendable {
            public var service: String?
            public var label: String
            public var minutes: Int
            public var text: String
            public var caption: String
            public var ends: StepEnds
            public var id: String { service ?? "" }

            public init(service: String?, label: String, minutes: Int, text: String, caption: String) {
                self.service = service
                self.label = label
                self.minutes = minutes
                self.text = text
                self.caption = caption
                ends = StepRange.ride.ends(minutes)
            }
        }

        public var rideRows: [RideRow] {
            guard !services.isEmpty else {
                return [RideRow(service: nil, label: strings.tr("c2.ride"), minutes: ride, text: strings.tr("c2.minutes", ride),
                                caption: strings.tr("s3.ride.caption"))]
            }
            return services.enumerated().map { index, service in
                let minutes = rides[service] ?? ride
                return RideRow(service: service, label: index == 0 ? strings.tr("c2.ride") : "", minutes: minutes,
                               text: strings.tr("c2.minutes", minutes), caption: strings.tr("c2.ride.on", service))
            }
        }

        /// Spec "Several buses" (v61): each bus that changes is one more pill after the buses at the
        /// stop, "12 · 34 → 33" (the arrow drawn); a tap opens its C2c.
        public var changePills: [ChangePill] { ChangePill.pills(changes, join: strings.tr("bus.join")) }

        /// Board C2's side column and stepper captions.
        public var sideTitle: String { strings.tr("c2.side.title", kidName) }

        /// The route as it stands, saved on every change. A route with no buses left is saved empty, so
        /// taking off the last bus (or removing the only bus that changes) sticks (review of #159).
        public var plan: BusPlan? {
            guard search.stop.count == 5 else { return nil }
            return BusPlan(kid: kid, stop: search.stop, services: services, walk: walk, ride: ride, lateGrace: lateGrace,
                           rides: rides.filter { services.contains($0.key) }, changes: changes)
        }

        /// The Buses row shows pills once the stop's buses are known (or a bus that changes exists);
        /// before that it reads "Pick the stop first".
        public var hasPills: Bool { !search.servicesAtStop.isEmpty || !changes.isEmpty }

        /// The link under the last Ride row (spec "Several buses", v61): "+ A bus that changes…"
        /// always shows and opens C2c for a new one.
        public var changeLink: String { strings.tr("c2.change_link") }

        /// C2c for one of the buses that change (`index`), or a new one (nil): our stop as this
        /// screen has it, the route's buses that change and its ride.
        public func changeEditor(index: Int?) -> ChangeBusesFeature.State {
            ChangeBusesFeature.State(ourStop: search, changes: changes, index: index, ride: ride)
        }
    }

    /// A bus that changes as a pill: its first buses ("12 · 34"), the drawn arrow, then its second bus.
    public struct ChangePill: Equatable, Identifiable, Sendable {
        public var index: Int
        public var title: String
        public var then: String
        public var id: Int { index }

        public init(index: Int, title: String, then: String) {
            self.index = index
            self.title = title
            self.then = then
        }

        /// One pill per bus that changes, its first buses joined by `join` (" · ").
        public static func pills(_ changes: [BusChange], join: String) -> [ChangePill] {
            changes.enumerated().map { ChangePill(index: $0, title: $1.firstBuses.joined(separator: join), then: $1.thenBus) }
        }
    }

    public enum Action: Equatable {
        case task
        case loaded(ScheduleSnapshot?)
        case search(StopSearchFeature.Action)
        case serviceTapped(String)
        case walkChanged(Int)
        case rideChanged(service: String?, minutes: Int)
        case graceChanged(Int)
        case changeLinkTapped
        case changeTapped(Int)
        /// Back from C2c: the route's buses that change as saved there.
        case changesSaved([BusChange])
        case doneTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case finished
            /// C2c for one bus that changes (its index), or a new one (nil).
            case openChange(index: Int?)
        }
    }

    @Dependency(\.scheduleStore) var scheduleStore

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.search, action: \.search) { StopSearchFeature() }
        Reduce { state, action in
            switch action {
            case .task:
                guard !state.isLoaded else { return .none }
                return .run { [scheduleStore] send in
                    await send(.loaded(try? await scheduleStore.load()))
                }

            case let .loaded(snapshot):
                state.isLoaded = true
                let kid = snapshot?.kids.first { $0.id == state.kid }
                state.kidName = kid?.name ?? ""
                state.storedKid = kid
                if let plan = snapshot?.busPlans.route(kid: state.kid) {
                    // Back from C2c the stop is the same: keep its name and buses instead of looking
                    // them up again (user, 2026-11-21).
                    if plan.stop != state.search.stop { state.search = StopSearchFeature.State(stop: plan.stop) }
                    state.services = plan.services
                    state.walk = plan.walk
                    state.ride = plan.ride
                    state.rides = Dictionary(uniqueKeysWithValues: plan.services.map { ($0, plan.ride(on: $0)) })
                    state.lateGrace = plan.lateGrace
                    state.changes = plan.changes
                }
                if let grace = kid?.school?.lateGrace { state.lateGrace = grace }
                // The stop's buses load once per visit; a reload keeps the list it has.
                return state.search.servicesAtStop.isEmpty ? .send(.search(.lookUp)) : .none

            case .search(.stopLooked):
                // The pills follow the stop's order once its buses are known.
                state.services = state.services.sorted { rank($0, in: state) < rank($1, in: state) }
                return .none

            case .search:
                return .none

            case let .serviceTapped(service):
                state.services = BusPlan.toggling(service, in: state.services, order: state.search.servicesAtStop)
                if state.services.contains(service), state.rides[service] == nil { state.rides[service] = state.ride }
                return save(state)

            case let .walkChanged(value):
                state.walk = StepRange.walk.clamp(value)
                return save(state)

            case let .rideChanged(service, minutes):
                let value = StepRange.ride.clamp(minutes)
                if let service { state.rides[service] = value } else { state.ride = value }
                return save(state)

            case let .graceChanged(value):
                state.lateGrace = StepRange.lateGrace.clamp(value)
                guard var kid = state.storedKid, let arriveBy = kid.school?.arriveBy else { return save(state) }
                kid.school?.latest = arriveBy + state.lateGrace
                state.storedKid = kid
                return .merge(save(state), .run { [scheduleStore, kid] _ in try? await scheduleStore.saveKid(kid) })

            case .changeLinkTapped:
                return .send(.delegate(.openChange(index: nil)))

            case let .changeTapped(index):
                guard state.changes.indices.contains(index) else { return .none }
                return .send(.delegate(.openChange(index: index)))

            case let .changesSaved(changes):
                state.changes = changes
                return save(state)

            case .doneTapped:
                return .send(.delegate(.finished))

            case .delegate:
                return .none
            }
        }
    }

    private func rank(_ service: String, in state: State) -> Int {
        state.search.servicesAtStop.firstIndex(of: service) ?? state.search.servicesAtStop.count
    }

    private func save(_ state: State) -> Effect<Action> {
        guard let plan = state.plan else { return .none }
        return .run { [scheduleStore] _ in try? await scheduleStore.saveBusPlan(plan) }
    }
}
