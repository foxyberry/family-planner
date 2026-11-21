import BusClient
import ComposableArchitecture
import CrayonKit
import Domain
import Foundation
import Localization
import Strings

/// C2c · A bus that changes (spec "Several buses", layout v61): one or more first buses from our
/// stop, then a second bus typed by its number, a Ride 1 per first bus, Change and Ride 2. No change
/// stop: each trip is the times as set. It edits one bus that changes of a route, new or existing,
/// in memory: Save and Remove hand the route's buses that change back to the screen that opened it
/// (C2 saves them at once, S3 with the plan at Start); ← leaves without saving.
@Reducer
public struct ChangeBusesFeature {
    @ObservableState
    public struct State: Equatable {
        public var strings = Localizer.injected
        /// Our stop (read-only): its name and the buses that call there, as the opening screen has them.
        public var ourStop: StopSearchFeature.State
        /// The route's buses that change as they are now; Save and Remove return a new list.
        public var changes: [BusChange]
        /// Which of `changes` this screen edits; nil for a new one.
        public var index: Int?
        /// The picked first buses, in pill order.
        public var firstBuses: [String] = []
        /// The Ride 1 a newly picked first bus starts with (the route's ride; with none picked, the
        /// one Ride 1 row sets it).
        public var ride1: Int
        /// Each picked first bus's own Ride 1.
        public var rides1: [String: Int] = [:]
        /// "Then": the second bus's number as typed.
        public var thenText = ""
        /// LTA's answer for `thenText`: nil while unknown (not checked yet, or no key / no network).
        public var thenIsService: Bool?
        public var change = BusChange.defaultChange
        public var ride2 = BusPlan.defaultRide
        /// The shared ConfirmCard: "Leave without saving?" (the C3x rule) or "Remove 12 · 34 → 33?".
        public var confirm: Confirm?

        public enum Confirm: Equatable, Sendable { case leave, remove }

        /// - Parameters: `ride` the route's ride, which a new first bus starts with.
        public init(ourStop: StopSearchFeature.State, changes: [BusChange], index: Int?, ride: Int = BusPlan.defaultRide) {
            self.ourStop = ourStop
            self.changes = changes
            self.index = index.flatMap { changes.indices.contains($0) ? $0 : nil }
            ride1 = ride
            if let original {
                firstBuses = original.firstBuses
                rides1 = original.rides1
                thenText = original.thenBus
                thenIsService = true
                change = original.change
                ride2 = original.ride2
            }
        }

        /// The bus that changes as it was when the screen opened (nil: a new one).
        public var original: BusChange? { index.map { changes[$0] } }

        public var title: String { strings.tr("c2c.title") }
        public var fromLabel: String { strings.tr("c2c.from") }
        public var fromName: String { ourStop.pickedStop?.name ?? ourStop.stop }
        public var ourStopCaption: String { strings.tr("c2c.our_stop") }
        public var firstBusLabel: String { strings.tr("c2c.first_bus") }
        public var noBusesText: String { strings.tr("c2.buses.none") }
        public var thenLabel: String { strings.tr("c2c.then") }
        public var thenPlaceholder: String { strings.tr("c2c.then.placeholder") }
        public var changeLabel: String { strings.tr("c2c.change") }
        public var changeCaption: String { strings.tr("c2c.change.caption") }
        public var ride2Label: String { strings.tr("c2c.ride2") }
        public var saveTitle: String { strings.tr("c2c.save") }
        public var changeText: String { strings.tr("c2.minutes", change) }
        public var ride2Text: String { strings.tr("c2.minutes", ride2) }
        public var ride2Caption: String { thenBus.map { strings.tr("c2.ride.on", $0) } ?? "" }

        /// The buses at our stop, one pill each; the picked ones are on.
        public struct Pill: Equatable, Identifiable, Sendable {
            public var service: String
            public var isOn: Bool
            public var id: String { service }
        }

        public var pills: [Pill] {
            ourStop.servicesAtStop.map { Pill(service: $0, isOn: firstBuses.contains($0)) }
        }

        /// Ride 1: one row per picked first bus, in pill order ("on 12"), the label "Ride 1" on the
        /// first only. With no first bus picked, one row sets the Ride 1 a new pick starts with.
        public var ride1Rows: [BusSettingsFeature.State.RideRow] {
            let label = strings.tr("c2c.ride1")
            guard !firstBuses.isEmpty else {
                return [.init(service: nil, label: label, minutes: ride1, text: strings.tr("c2.minutes", ride1), caption: "")]
            }
            return firstBuses.enumerated().map { index, bus in
                let minutes = rides1[bus] ?? ride1
                return .init(service: bus, label: index == 0 ? label : "", minutes: minutes,
                             text: strings.tr("c2.minutes", minutes), caption: strings.tr("c2.ride.on", bus))
            }
        }

        /// The typed second bus once it reads as a bus number that is not one of the first buses.
        public var thenBus: String? {
            let number = thenText.trimmingCharacters(in: .whitespaces).uppercased()
            guard BusChange.isServiceNumber(number), !firstBuses.contains(number) else { return nil }
            return number
        }

        /// "Then" shows a problem: not a bus number, or one LTA does not run.
        public var thenHasProblem: Bool {
            !thenText.isEmpty && (thenBus == nil || thenIsService == false)
        }

        /// The caption under "Then": "No bus with that number" when it is wrong, else nothing.
        public var thenCaption: String? { thenHasProblem ? strings.tr("c2c.then.unknown") : nil }

        /// The bus that changes as set, once a first bus and the second bus are there and the second
        /// one is known to LTA (or LTA cannot be asked).
        public var busChange: BusChange? {
            guard !firstBuses.isEmpty, let thenBus, thenIsService != false else { return nil }
            return BusChange(firstBuses: firstBuses, thenBus: thenBus,
                             rides1: Dictionary(uniqueKeysWithValues: firstBuses.map { ($0, rides1[$0] ?? ride1) }),
                             change: change, ride2: ride2)
        }

        /// Something differs from the bus as it was: ← asks first.
        public var hasChanges: Bool {
            if let original { return busChange != original }
            return !firstBuses.isEmpty || !thenText.isEmpty
        }

        public var canSave: Bool { busChange != nil }

        /// The side column's head (layout v61): "12 · 34 → 33" with the arrow drawn (at the format's
        /// `%@`), the first buses alone until Then is set, nothing before a first bus is picked.
        public enum Head: Equatable, Sendable {
            case buses(String)
            case change(format: String)
        }

        public var head: Head? {
            guard !firstBuses.isEmpty else { return nil }
            let firsts = firstBuses.joined(separator: strings.tr("bus.join"))
            guard let thenBus else { return .buses(firsts) }
            return .change(format: Self.glyphName(firsts: firsts, then: thenBus))
        }

        /// "Remove this bus", for a bus that changes that already exists.
        public var removeTitle: String? { original == nil ? nil : strings.tr("c2c.remove") }

        /// "12 · 34 %@ 33": the arrow is drawn at `%@` (Playpen Sans has no arrows).
        static func glyphName(firsts: String, then: String) -> String { "\(firsts) %@ \(then)" }

        /// The ConfirmCard (shared): its title has the bus's arrow drawn at `%@` when it removes.
        public struct ConfirmWords: Equatable, Sendable {
            public var title: String
            public var titleGlyph: MarkerGlyph?
            public var cancel: String
            public var accept: String
        }

        public var confirmWords: ConfirmWords? {
            switch confirm {
            case .leave:
                return ConfirmWords(title: strings.tr("editor.confirm.leave.title"), titleGlyph: nil,
                                    cancel: strings.tr("editor.confirm.leave.cancel"),
                                    accept: strings.tr("editor.confirm.leave.accept"))
            case .remove:
                guard let original else { return nil }
                let name = Self.glyphName(firsts: original.firstBuses.joined(separator: strings.tr("bus.join")),
                                          then: original.thenBus)
                return ConfirmWords(title: strings.tr("c2c.remove.title", name), titleGlyph: .arrowRight,
                                    cancel: strings.tr("c2c.remove.keep"), accept: strings.tr("c2c.remove.accept"))
            case nil:
                return nil
            }
        }

        /// Board C3x: "Leave without saving?" points at "←"; the remove card sits over the screen.
        public var confirmPointsAtBack: Bool { confirm == .leave }
    }

    public enum Action: Equatable {
        case task
        case ourStop(StopSearchFeature.Action)
        case firstBusTapped(String)
        case thenChanged(String)
        case thenChecked(String, isService: Bool?)
        case ride1Changed(service: String?, minutes: Int)
        case changeChanged(Int)
        case ride2Changed(Int)
        case saveTapped
        case removeTapped
        case backTapped
        case confirmAccepted
        case confirmCancelled
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// Save or Remove: the route's buses that change as they are now.
            case saved([BusChange])
            /// ← with nothing to keep, or "Leave": nothing changed.
            case cancelled
        }
    }

    @Dependency(\.bus) var bus
    @Dependency(\.continuousClock) var clock

    private enum CheckID: Hashable { case then }

    public init() {}

    public var body: some ReducerOf<Self> {
        Scope(state: \.ourStop, action: \.ourStop) { StopSearchFeature() }
        Reduce { state, action in
            switch action {
            case .task:
                // The opening screen has our stop's buses; look them up only when it had none yet.
                guard state.ourStop.servicesAtStop.isEmpty, state.ourStop.stop.count == 5 else { return .none }
                return .send(.ourStop(.lookUp))

            case .ourStop:
                return .none

            case let .firstBusTapped(service):
                state.firstBuses = BusPlan.toggling(service, in: state.firstBuses, order: state.ourStop.servicesAtStop)
                if state.firstBuses.contains(service), state.rides1[service] == nil { state.rides1[service] = state.ride1 }
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

            case let .ride1Changed(service, minutes):
                let value = min(max(minutes, 0), 90)
                if let service { state.rides1[service] = value } else { state.ride1 = value }
                return .none

            case let .changeChanged(value):
                state.change = min(max(value, 0), 30)
                return .none

            case let .ride2Changed(value):
                state.ride2 = min(max(value, 0), 90)
                return .none

            case .saveTapped:
                guard let change = state.busChange else { return .none }
                var changes = state.changes
                if let index = state.index { changes[index] = change } else { changes.append(change) }
                return .send(.delegate(.saved(changes)))

            case .removeTapped:
                guard state.original != nil else { return .none }
                state.confirm = .remove
                return .none

            case .backTapped:
                guard state.hasChanges else { return .send(.delegate(.cancelled)) }
                state.confirm = .leave
                return .none

            case .confirmCancelled:
                state.confirm = nil
                return .none

            case .confirmAccepted:
                let confirm = state.confirm
                state.confirm = nil
                switch confirm {
                case .leave:
                    return .send(.delegate(.cancelled))
                case .remove:
                    guard let index = state.index else { return .none }
                    var changes = state.changes
                    changes.remove(at: index)
                    return .send(.delegate(.saved(changes)))
                case nil:
                    return .none
                }

            case .delegate:
                return .none
            }
        }
    }
}
