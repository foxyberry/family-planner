import BusClient
import ComposableArchitecture
import Domain
import Foundation
import Strings

/// The stop field of C2 and S3 (spec "Bus settings", user review PR #24): a stop name to search for
/// or the 5-digit code on its pole; picking a match (or typing a known code) fills the code, shows
/// the stop's road and code, and lists the bus numbers that call there now.
@Reducer
public struct StopSearchFeature {
    @ObservableState
    public struct State: Equatable {
        /// The 5-digit code, once known.
        public var stop = ""
        /// The stop the code belongs to (picked from the list or looked up from the code).
        public var pickedStop: BusStop?
        /// What the field shows: a name to search for, the code, or the picked stop's name.
        public var text = ""
        /// Stops whose name or road matches `text` (at most 8).
        public var matches: [BusStop] = []
        /// Bus numbers that call at the stop (from its live arrivals).
        public var servicesAtStop: [String] = []

        public init(stop: String = "") {
            self.stop = stop
            text = stop
        }

        /// The result list is open while there are matches (layout v14 veils the screen meanwhile).
        public var isListOpen: Bool { !matches.isEmpty }

        /// The name under the field, or a hint while it is not 5 digits or unknown.
        public var caption: String {
            if let pickedStop { return L10n.tr("c2.stop.match", pickedStop.road, pickedStop.code) }
            if !matches.isEmpty { return L10n.tr("c2.stop.pick") }
            if text.filter(\.isLetter).count >= 2 { return L10n.tr("c2.stop.none_found") }
            return stop.count == 5 ? L10n.tr("c2.stop.unknown") : L10n.tr("c2.stop.hint")
        }
    }

    public enum Action: Equatable {
        case textChanged(String)
        case stopsFound([BusStop])
        case stopPicked(BusStop)
        case stopLooked(stop: BusStop?, services: [String])
        /// Looks up the stored code's name and buses (after a load).
        case lookUp
        /// A tap on the veil around the open list closes it; the typed text stays.
        case listClosed
    }

    @Dependency(\.bus) var bus

    public init() {}

    private enum SearchID: Hashable { case stops, lookUp }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .textChanged(text):
                state.text = text
                state.pickedStop = nil
                state.servicesAtStop = []
                // Two or more letters: a name to look for; otherwise the digits of the code.
                if text.filter(\.isLetter).count >= 2 {
                    state.stop = ""
                    return .run { [bus] send in
                        try await Task.sleep(for: .milliseconds(300))
                        await send(.stopsFound((try? await bus.searchStops(text)) ?? []))
                    }
                    .cancellable(id: SearchID.stops, cancelInFlight: true)
                }
                state.matches = []
                state.stop = String(text.filter(\.isNumber).prefix(5))
                return .merge(.cancel(id: SearchID.stops), lookUp(state))

            case let .stopsFound(stops):
                state.matches = stops
                return .none

            case let .stopPicked(stop):
                state.stop = stop.code
                // Board C2 (v9): the field shows the stop's name, the caption its road and code.
                state.text = stop.name
                state.pickedStop = stop
                state.matches = []
                return lookUp(state)

            case let .stopLooked(stop, services):
                if let stop, stop.code == state.stop {
                    state.pickedStop = stop
                    state.text = stop.name
                }
                state.servicesAtStop = services
                return .none

            case .lookUp:
                return lookUp(state)

            case .listClosed:
                state.matches = []
                return .merge(.cancel(id: SearchID.stops), .cancel(id: SearchID.lookUp))
            }
        }
    }

    /// With a 5-digit stop: the stop's name and the bus numbers calling there now (nothing without a key).
    private func lookUp(_ state: State) -> Effect<Action> {
        guard state.stop.count == 5 else { return .none }
        let stop = state.stop
        return .run { [bus] send in
            let found = try? await bus.stop(stop)
            let arrivals = (try? await bus.arrivals(stop)) ?? []
            var seen: [String] = []
            for arrival in arrivals where !seen.contains(arrival.service) { seen.append(arrival.service) }
            await send(.stopLooked(stop: found, services: seen.sorted { $0.localizedStandardCompare($1) == .orderedAscending }))
        }
        // A newer code (or closing the field) replaces a lookup still running.
        .cancellable(id: SearchID.lookUp, cancelInFlight: true)
    }
}
