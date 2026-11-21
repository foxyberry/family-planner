import BusClient
import ComposableArchitecture
import Domain
import Foundation
import Localization
import ScheduleStore
import Strings

/// C2c · A bus that changes (spec "Several buses"): a first bus from our stop, then a second bus
/// typed by its number, and Ride 1 / Change / Ride 2. No change stop: the trip is the three times as
/// set. Save stores it as one more equal bus of the kid; ← leaves without saving.
@Reducer
public struct ChangeBusesFeature {
    @ObservableState
    public struct State: Equatable {
        public var strings = Localizer.injected
        public var kid: Kid.ID
        /// The route as stored; Save changes its bus that changes only.
        public var plan: BusPlan?
        /// Our stop (read-only): its name and the buses that call there.
        public var ourStop = StopSearchFeature.State()
        public var firstBus: String?
        /// "Then": the second bus's number as typed.
        public var thenText = ""
        /// LTA's answer for `thenText`: nil while unknown (not checked yet, or no key / no network).
        public var thenIsService: Bool?
        public var ride1 = BusPlan.defaultRide
        public var change = BusChange.defaultChange
        public var ride2 = BusPlan.defaultRide
        /// "Leave without saving?" (the C3x rule) after ← with unsaved changes.
        public var isConfirmingLeave = false

        public init(kid: Kid.ID) {
            self.kid = kid
        }

        public var title: String { L10n.tr("c2c.title") }
        public var fromName: String { ourStop.pickedStop?.name ?? ourStop.stop }
        public var ride1Text: String { L10n.tr("c2.minutes", ride1) }
        public var changeText: String { L10n.tr("c2.minutes", change) }
        public var ride2Text: String { L10n.tr("c2.minutes", ride2) }
        public var ride1Caption: String { firstBus.map { L10n.tr("c2.ride.on", $0) } ?? "" }
        public var ride2Caption: String { thenBus.map { L10n.tr("c2.ride.on", $0) } ?? "" }
        /// The buses at our stop.
        public var firstBuses: [String] { ourStop.servicesAtStop }

        /// The typed second bus once it reads as a bus number other than the first bus.
        public var thenBus: String? {
            let number = thenText.trimmingCharacters(in: .whitespaces).uppercased()
            guard BusChange.isServiceNumber(number), number != firstBus else { return nil }
            return number
        }

        /// "Then" shows a problem: not a bus number, or one LTA does not run.
        public var thenHasProblem: Bool {
            !thenText.isEmpty && (thenBus == nil || thenIsService == false)
        }

        /// The caption under "Then": "No bus with that number" when it is wrong, else nothing.
        public var thenCaption: String? { thenHasProblem ? L10n.tr("c2c.then.unknown") : nil }

        /// The bus that changes as set, once both buses are there and the second one is known to LTA
        /// (or LTA cannot be asked).
        public var busChange: BusChange? {
            guard let firstBus, let thenBus, thenIsService != false else { return nil }
            return BusChange(firstBus: firstBus, thenBus: thenBus, ride1: ride1, change: change, ride2: ride2)
        }

        /// Something differs from the stored bus that changes: ← asks first.
        public var hasChanges: Bool {
            guard let plan else { return false }
            if busChange != plan.change { return true }
            return plan.change == nil && (firstBus != nil || !thenText.isEmpty)
        }

        /// Save keeps a whole bus that changes, or removes the stored one when both buses were cleared.
        public var canSave: Bool {
            guard plan != nil else { return false }
            return busChange != nil || (firstBus == nil && thenText.isEmpty && plan?.change != nil)
        }
    }

    public enum Action: Equatable {
        case task
        case loaded(ScheduleSnapshot?)
        case ourStop(StopSearchFeature.Action)
        case firstBusTapped(String)
        case thenChanged(String)
        case thenChecked(String, isService: Bool?)
        case ride1Changed(Int)
        case changeChanged(Int)
        case ride2Changed(Int)
        case saveTapped
        case backTapped
        case leaveConfirmed
        case leaveCancelled
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case finished
        }
    }

    @Dependency(\.scheduleStore) var scheduleStore
    @Dependency(\.bus) var bus
    @Dependency(\.continuousClock) var clock

    private enum CheckID: Hashable { case then }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.ourStop, action: \.ourStop) { StopSearchFeature() }
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
                if let change = plan.change {
                    state.firstBus = change.firstBus
                    state.thenText = change.thenBus
                    state.thenIsService = true
                    state.ride1 = change.ride1
                    state.change = change.change
                    state.ride2 = change.ride2
                } else {
                    state.ride1 = plan.ride
                }
                return .send(.ourStop(.lookUp))

            case .ourStop:
                return .none

            case let .firstBusTapped(service):
                state.firstBus = state.firstBus == service ? nil : service
                return .none

            case let .thenChanged(text):
                state.thenText = String(text.prefix(4))
                state.thenIsService = nil
                guard let number = state.thenBus else { return .cancel(id: CheckID.then) }
                return .run { [bus, clock] send in
                    try await clock.sleep(for: .milliseconds(400))
                    await send(.thenChecked(number, isService: try? await bus.isService(number)))
                }
                .cancellable(id: CheckID.then, cancelInFlight: true)

            case let .thenChecked(number, isService):
                guard number == state.thenBus else { return .none }
                state.thenIsService = isService
                return .none

            case let .ride1Changed(value):
                state.ride1 = min(max(value, 0), 90)
                return .none

            case let .changeChanged(value):
                state.change = min(max(value, 0), 30)
                return .none

            case let .ride2Changed(value):
                state.ride2 = min(max(value, 0), 90)
                return .none

            case .saveTapped:
                guard state.canSave, var plan = state.plan else { return .none }
                plan.change = state.busChange
                return .run { [scheduleStore, plan] send in
                    try? await scheduleStore.saveBusPlan(plan)
                    await send(.delegate(.finished))
                }

            case .backTapped:
                guard state.hasChanges else { return .send(.delegate(.finished)) }
                state.isConfirmingLeave = true
                return .none

            case .leaveCancelled:
                state.isConfirmingLeave = false
                return .none

            case .leaveConfirmed:
                state.isConfirmingLeave = false
                return .send(.delegate(.finished))

            case .delegate:
                return .none
            }
        }
    }
}
