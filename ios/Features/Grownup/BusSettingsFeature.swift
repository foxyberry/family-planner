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

        public init(kid: Kid.ID) {
            self.kid = kid
        }

        public var title: String { L10n.tr("c2.title") }
        public var walkText: String { L10n.tr("c2.minutes", walk) }
        public var rideText: String { L10n.tr("c2.minutes", ride) }
        public var graceText: String { L10n.tr("c2.minutes", lateGrace) }

        public var plan: BusPlan? {
            guard search.stop.count == 5, !services.isEmpty else { return nil }
            return BusPlan(kid: kid, stop: search.stop, services: services, walk: walk, ride: ride, lateGrace: lateGrace)
        }
    }

    public enum Action: Equatable {
        case task
        case loaded(ScheduleSnapshot?)
        case search(StopSearchFeature.Action)
        case serviceTapped(String)
        case walkChanged(Int)
        case rideChanged(Int)
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
                state.kidName = snapshot?.kids.first { $0.id == state.kid }?.name ?? ""
                if let plan = snapshot?.busPlans.first(where: { $0.kid == state.kid }) {
                    state.search = StopSearchFeature.State(stop: plan.stop)
                    state.services = plan.services
                    state.walk = plan.walk
                    state.ride = plan.ride
                    state.lateGrace = plan.lateGrace
                }
                return .send(.search(.lookUp))

            case .search:
                return .none

            case let .serviceTapped(service):
                if let index = state.services.firstIndex(of: service) {
                    state.services.remove(at: index)
                } else {
                    state.services.append(service)
                }
                return save(state)

            case let .walkChanged(value):
                state.walk = min(max(value, 0), 60)
                return save(state)

            case let .rideChanged(value):
                state.ride = min(max(value, 0), 90)
                return save(state)

            case let .graceChanged(value):
                state.lateGrace = min(max(value, 0), 30)
                return save(state)

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
