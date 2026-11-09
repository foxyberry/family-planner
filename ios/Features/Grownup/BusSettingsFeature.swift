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
        public var stop = ""
        public var stopName: String?
        /// The stop field: a name to search for, or the 5-digit code.
        public var stopText = ""
        /// Stops whose name or road matches `stopText` (user, 2026-11-09: families know the name).
        public var stopMatches: [BusStop] = []
        /// Bus numbers that call at the stop (from its live arrivals), and the kid's picks.
        public var servicesAtStop: [String] = []
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

        /// The name under the stop code, or a hint while it is not 5 digits or unknown.
        public var stopCaption: String {
            if let stopName { return stopName }
            if !stopMatches.isEmpty { return L10n.tr("c2.stop.pick") }
            if stopText.filter(\.isLetter).count >= 2 { return L10n.tr("c2.stop.none_found") }
            return stop.count == 5 ? L10n.tr("c2.stop.unknown") : L10n.tr("c2.stop.hint")
        }

        public var plan: BusPlan? {
            guard stop.count == 5, !services.isEmpty else { return nil }
            return BusPlan(kid: kid, stop: stop, services: services, walk: walk, ride: ride, lateGrace: lateGrace)
        }
    }

    public enum Action: Equatable {
        case task
        case loaded(ScheduleSnapshot?)
        case stopChanged(String)
        case stopsFound([BusStop])
        case stopPicked(BusStop)
        case stopLooked(name: String?, services: [String])
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
    @Dependency(\.bus) var bus

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return .run { [scheduleStore] send in
                    await send(.loaded(try? await scheduleStore.load()))
                }

            case let .loaded(snapshot):
                state.kidName = snapshot?.kids.first { $0.id == state.kid }?.name ?? ""
                if let plan = snapshot?.busPlans.first(where: { $0.kid == state.kid }) {
                    state.stop = plan.stop
                    state.stopText = plan.stop
                    state.services = plan.services
                    state.walk = plan.walk
                    state.ride = plan.ride
                    state.lateGrace = plan.lateGrace
                }
                return lookUp(state)

            case let .stopChanged(text):
                state.stopText = text
                state.stopName = nil
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
                state.stopMatches = []
                state.stop = String(text.filter(\.isNumber).prefix(5))
                return .merge(.cancel(id: SearchID.stops), lookUp(state))

            case let .stopsFound(stops):
                state.stopMatches = stops
                return .none

            case let .stopPicked(stop):
                state.stop = stop.code
                state.stopText = stop.code
                state.stopName = stop.name
                state.stopMatches = []
                return lookUp(state)

            case let .stopLooked(name, services):
                state.stopName = name
                state.servicesAtStop = services
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

    private enum SearchID: Hashable { case stops }

    /// With a 5-digit stop: the stop's name and the bus numbers calling there now (nothing without a key).
    private func lookUp(_ state: State) -> Effect<Action> {
        guard state.stop.count == 5 else { return .none }
        let stop = state.stop
        return .run { [bus] send in
            let name = try? await bus.stopName(stop)
            let arrivals = (try? await bus.arrivals(stop)) ?? []
            var seen: [String] = []
            for arrival in arrivals where !seen.contains(arrival.service) { seen.append(arrival.service) }
            await send(.stopLooked(name: name, services: seen.sorted { $0.localizedStandardCompare($1) == .orderedAscending }))
        }
    }

    private func save(_ state: State) -> Effect<Action> {
        guard let plan = state.plan else { return .none }
        return .run { [scheduleStore] _ in try? await scheduleStore.saveBusPlan(plan) }
    }
}
