import BusClient
import ComposableArchitecture
import Domain
import Foundation
import ScheduleStore
import Strings

/// C2 · Our buses (spec "Bus settings", first cut): plan A only. The stop code with its name as a
/// check, the kid's bus numbers as chips from what calls at the stop, and walk / ride / late grace.
/// Live times use the key built into the app; stop codes and numbers never leave the iPad.
@Reducer
public struct BusSettingsFeature {
    @ObservableState
    public struct State: Equatable {
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
        /// The bus that changes (C2c), one more equal bus.
        public var change: BusChange?
        /// The kid as stored: "Late" is their school's Latest − Arrive by when the school has both
        /// (spec "Latest lives on the school record"), else the plan's own value.
        public var storedKid: Kid?

        public init(kid: Kid.ID) {
            self.kid = kid
        }

        public var title: String { L10n.tr("c2.title") }
        public var walkText: String { L10n.tr("c2.minutes", walk) }
        public var graceText: String { L10n.tr("c2.minutes", lateGrace) }

        /// One Ride row per picked bus, in pill order ("on 12"); the label "Ride" on the first only.
        public struct RideRow: Equatable, Identifiable, Sendable {
            public var service: String
            public var label: String
            public var minutes: Int
            public var text: String
            public var caption: String
            /// VoiceOver names every row ("Ride on 34"), also those without a label.
            public var spoken: String
            public var id: String { service }
        }

        public var rideRows: [RideRow] {
            services.enumerated().map { index, service in
                let minutes = rides[service] ?? ride
                return RideRow(service: service, label: index == 0 ? L10n.tr("c2.ride") : "", minutes: minutes,
                               text: L10n.tr("c2.minutes", minutes), caption: L10n.tr("c2.ride.on", service),
                               spoken: L10n.tr("c2.ride.spoken", service))
            }
        }

        /// Board C2's side column and stepper captions.
        public var sideTitle: String { L10n.tr("c2.side.title", kidName) }

        public var plan: BusPlan? {
            guard search.stop.count == 5, !services.isEmpty || change != nil else { return nil }
            return BusPlan(kid: kid, stop: search.stop, services: services, walk: walk, ride: ride, lateGrace: lateGrace,
                           rides: rides.filter { services.contains($0.key) }, change: change)
        }

        /// The link under the rows (spec "Several buses"): "+ A bus that changes…" while the kid has no
        /// bus that changes, at a known stop; a picked one is a pill ("34 → 33") instead.
        public var showsChangeLink: Bool { search.stop.count == 5 && !search.servicesAtStop.isEmpty && change == nil }
        public var changeLink: String { L10n.tr("c2.change_link") }
    }

    public enum Action: Equatable {
        case task
        case loaded(ScheduleSnapshot?)
        case search(StopSearchFeature.Action)
        case serviceTapped(String)
        case walkChanged(Int)
        case rideChanged(service: String, minutes: Int)
        case graceChanged(Int)
        case changeLinkTapped
        case doneTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case finished
            case openChange(Kid.ID)
        }
    }

    @Dependency(\.scheduleStore) var scheduleStore

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.search, action: \.search) { StopSearchFeature() }
        Reduce { state, action in
            switch action {
            case .task:
                return .run { [scheduleStore] send in
                    await send(.loaded(try? await scheduleStore.load()))
                }

            case let .loaded(snapshot):
                let kid = snapshot?.kids.first { $0.id == state.kid }
                state.kidName = kid?.name ?? ""
                state.storedKid = kid
                if let plan = snapshot?.busPlans.route(kid: state.kid) {
                    state.search = StopSearchFeature.State(stop: plan.stop)
                    state.services = plan.services
                    state.walk = plan.walk
                    state.ride = plan.ride
                    state.rides = Dictionary(uniqueKeysWithValues: plan.services.map { ($0, plan.ride(on: $0)) })
                    state.lateGrace = plan.lateGrace
                    state.change = plan.change
                }
                if let grace = kid?.school?.lateGrace { state.lateGrace = grace }
                return .send(.search(.lookUp))

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
                state.walk = min(max(value, 0), 60)
                return save(state)

            case let .rideChanged(service, minutes):
                state.rides[service] = min(max(minutes, 0), 90)
                return save(state)

            case let .graceChanged(value):
                state.lateGrace = min(max(value, 0), 30)
                guard var kid = state.storedKid, let arriveBy = kid.school?.arriveBy else { return save(state) }
                kid.school?.latest = arriveBy + state.lateGrace
                state.storedKid = kid
                return .merge(save(state), .run { [scheduleStore, kid] _ in try? await scheduleStore.saveKid(kid) })

            case .changeLinkTapped:
                return .send(.delegate(.openChange(state.kid)))

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
