import BusClient
import ComposableArchitecture
import Domain
import Foundation
import ScheduleStore
import Strings

/// C2c · 2nd choice · change buses (spec "C2c"): a first bus from our stop, the change stop, the bus
/// from there, and the three times. Save stores it as the kid's 2nd choice (it replaces a direct 2nd);
/// ← leaves without saving.
@Reducer
public struct ChangeBusesFeature {
    @ObservableState
    public struct State: Equatable {
        public var kid: Kid.ID
        /// The route as stored; Save changes its 2nd choice only.
        public var plan: BusPlan?
        /// Our stop (read-only): its name and the buses that call there.
        public var ourStop = StopSearchFeature.State()
        /// The change stop's field.
        public var search = StopSearchFeature.State()
        public var firstBus: String?
        public var thenBus: String?
        public var ride1 = BusPlan.defaultRide
        public var walk = 2
        public var ride2 = BusPlan.defaultRide

        public init(kid: Kid.ID) {
            self.kid = kid
        }

        public var title: String { L10n.tr("c2c.title") }
        public var fromName: String { ourStop.pickedStop?.name ?? ourStop.stop }
        public var ride1Text: String { L10n.tr("c2.minutes", ride1) }
        public var walkText: String { L10n.tr("c2.minutes", walk) }
        public var ride2Text: String { L10n.tr("c2.minutes", ride2) }
        public var ride1Caption: String { firstBus.map { L10n.tr("c2.ride.on", $0) } ?? "" }
        public var ride2Caption: String { thenBus.map { L10n.tr("c2.ride.on", $0) } ?? "" }
        /// Buses at our stop other than the kid's 1st (the 2nd choice is another way).
        public var firstBuses: [String] { ourStop.servicesAtStop.filter { $0 != plan?.first } }
        /// Buses at the change stop, without the one the kid gets off.
        public var thenBuses: [String] { search.servicesAtStop.filter { $0 != firstBus } }

        /// The route as picked, once every part is there.
        public var change: BusChange? {
            guard let firstBus, let thenBus, search.stop.count == 5 else { return nil }
            return BusChange(firstBus: firstBus, stop: search.stop, thenBus: thenBus, ride1: ride1, walk: walk, ride2: ride2)
        }

        /// Save keeps a whole route, or removes the stored one when both buses were cleared.
        public var canSave: Bool {
            guard plan != nil else { return false }
            return change != nil || (firstBus == nil && thenBus == nil && plan?.change != nil)
        }
    }

    public enum Action: Equatable {
        case task
        case loaded(ScheduleSnapshot?)
        case ourStop(StopSearchFeature.Action)
        case search(StopSearchFeature.Action)
        case firstBusTapped(String)
        case thenBusTapped(String)
        case ride1Changed(Int)
        case walkChanged(Int)
        case ride2Changed(Int)
        case saveTapped
        case backTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case finished
        }
    }

    @Dependency(\.scheduleStore) var scheduleStore

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.ourStop, action: \.ourStop) { StopSearchFeature() }
        Scope(state: \.search, action: \.search) { StopSearchFeature() }
        Reduce { state, action in
            switch action {
            case .task:
                return .run { [scheduleStore] send in
                    await send(.loaded(try? await scheduleStore.load()))
                }

            case let .loaded(snapshot):
                guard let plan = snapshot?.busPlans.route(kid: state.kid) else { return .none }
                state.plan = plan
                state.ourStop = StopSearchFeature.State(stop: plan.stop)
                var effects: [Effect<Action>] = [.send(.ourStop(.lookUp))]
                if let change = plan.change {
                    state.firstBus = change.firstBus
                    state.thenBus = change.thenBus
                    state.ride1 = change.ride1
                    state.walk = change.walk
                    state.ride2 = change.ride2
                    state.search = StopSearchFeature.State(stop: change.stop)
                    effects.append(.send(.search(.lookUp)))
                } else {
                    state.ride1 = plan.ride
                }
                return .merge(effects)

            case .ourStop, .search:
                return .none

            case let .firstBusTapped(service):
                state.firstBus = state.firstBus == service ? nil : service
                if state.thenBus == state.firstBus { state.thenBus = nil }
                return .none

            case let .thenBusTapped(service):
                state.thenBus = state.thenBus == service ? nil : service
                return .none

            case let .ride1Changed(value):
                state.ride1 = min(max(value, 0), 90)
                return .none

            case let .walkChanged(value):
                state.walk = min(max(value, 0), 30)
                return .none

            case let .ride2Changed(value):
                state.ride2 = min(max(value, 0), 90)
                return .none

            case .saveTapped:
                guard state.canSave, let plan = state.plan else { return .none }
                let saved = plan.changing(state.change)
                return .run { [scheduleStore] send in
                    try? await scheduleStore.saveBusPlan(saved)
                    await send(.delegate(.finished))
                }

            case .backTapped:
                return .send(.delegate(.finished))

            case .delegate:
                return .none
            }
        }
    }
}
