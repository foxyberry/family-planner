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
        /// The kid's bus numbers, picked from what calls at the stop.
        public var services: [String] = []
        public var walk = BusPlan.defaultWalk
        public var ride = BusPlan.defaultRide
        public var lateGrace = BusPlan.defaultLateGrace
        /// "Ride 2nd" (spec "C2 rows"), shown while a 2nd bus is picked.
        public var secondRide = BusPlan.defaultRide
        /// The kid as stored: "Late" is their school's Latest − Arrive by when the school has both
        /// (spec "Latest lives on the school record"), else the plan's own value.
        public var storedKid: Kid?

        public init(kid: Kid.ID) {
            self.kid = kid
        }

        public var title: String { L10n.tr("c2.title") }
        public var walkText: String { L10n.tr("c2.minutes", walk) }
        public var rideText: String { L10n.tr("c2.minutes", ride) }
        public var graceText: String { L10n.tr("c2.minutes", lateGrace) }
        public var secondRideText: String { L10n.tr("c2.minutes", secondRide) }
        /// The 2nd bus, when one is picked: the "Ride 2nd" row shows.
        public var second: String? { services.count > 1 ? services[1] : nil }
        /// "on 34 · the long way".
        public var secondRideCaption: String { second.map { L10n.tr("c2.ride_second.on", $0) } ?? "" }
        /// A pill's tag: "1st", "2nd" or none.
        public func tag(for service: String) -> String? {
            switch services.firstIndex(of: service) {
            case 0?: L10n.tr("c2.tag.first")
            case 1?: L10n.tr("c2.tag.second")
            default: nil
            }
        }

        /// Board C2's side column and stepper captions.
        public var sideTitle: String { L10n.tr("c2.side.title", kidName) }
        /// "on 12" for the first picked bus, else what the ride covers.
        public var rideCaption: String {
            services.first.map { L10n.tr("c2.ride.on", $0) } ?? L10n.tr("s3.ride.caption")
        }

        public var plan: BusPlan? {
            guard search.stop.count == 5, !services.isEmpty else { return nil }
            return BusPlan(kid: kid, stop: search.stop, services: services, walk: walk, ride: ride, lateGrace: lateGrace,
                           secondRide: second == nil ? nil : secondRide)
        }
    }

    public enum Action: Equatable {
        case task
        case loaded(ScheduleSnapshot?)
        case search(StopSearchFeature.Action)
        case serviceTapped(String)
        case walkChanged(Int)
        case rideChanged(Int)
        case secondRideChanged(Int)
        case graceChanged(Int)
        case doneTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case finished
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
                    // Older plans could hold more buses; the 1st and 2nd are the first two.
                    state.services = Array(plan.services.prefix(2))
                    state.walk = plan.walk
                    state.ride = plan.ride
                    state.secondRide = plan.secondRide ?? plan.ride
                    state.lateGrace = plan.lateGrace
                }
                if let grace = kid?.school?.lateGrace { state.lateGrace = grace }
                return .send(.search(.lookUp))

            case .search:
                return .none

            case let .serviceTapped(service):
                let hadSecond = state.second != nil
                state.services = BusPlan.toggling(service, in: state.services)
                if !hadSecond, state.second != nil { state.secondRide = state.ride }
                return save(state)

            case let .walkChanged(value):
                state.walk = min(max(value, 0), 60)
                return save(state)

            case let .rideChanged(value):
                state.ride = min(max(value, 0), 90)
                return save(state)

            case let .secondRideChanged(value):
                state.secondRide = min(max(value, 0), 90)
                return save(state)

            case let .graceChanged(value):
                state.lateGrace = min(max(value, 0), 30)
                guard var kid = state.storedKid, let arriveBy = kid.school?.arriveBy else { return save(state) }
                kid.school?.latest = arriveBy + state.lateGrace
                state.storedKid = kid
                return .merge(save(state), .run { [scheduleStore, kid] _ in try? await scheduleStore.saveKid(kid) })

            case .doneTapped:
                return .send(.delegate(.finished))

            case .delegate:
                return .none
            }
        }
    }

    private func save(_ state: State) -> Effect<Action> {
        guard let plan = state.plan else { return .none }
        return .run { [scheduleStore] _ in try? await scheduleStore.saveBusPlan(plan) }
    }
}
