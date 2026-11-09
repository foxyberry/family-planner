import ComposableArchitecture
import Domain

/// Live bus times (LTA DataMall). Features use this interface; the app injects the live one,
/// which carries the key built into the app. Without a key the calls throw and screens show the
/// timetable instead.
@DependencyClient
public struct BusClient: Sendable {
    /// Arrivals at `stop` now: up to three per bus number, minutes from now.
    public var arrivals: @Sendable (_ stop: String) async throws -> [BusArrival]
    /// The stop with this 5-digit code (its name and road for the C2 confirm), or nil when unknown.
    public var stop: @Sendable (_ code: String) async throws -> BusStop?
    /// Stops whose name or road has every word of `text` (user, 2026-11-09: families know the
    /// name, not the 5-digit code), at most 8.
    public var searchStops: @Sendable (_ text: String) async throws -> [BusStop]
}

/// A bus stop from the LTA list: the 5-digit code on its pole, its name and road.
public struct BusStop: Equatable, Identifiable, Sendable {
    public var code: String
    public var name: String
    public var road: String
    public var id: String { code }

    public init(code: String, name: String, road: String) {
        self.code = code
        self.name = name
        self.road = road
    }
}

extension BusClient: TestDependencyKey {
    public static let testValue = Self()
    /// Made-up arrivals for previews (privacy rule: no real stops or buses).
    public static let previewValue = Self(
        arrivals: { _ in
            [BusArrival(service: "1", minutes: 4, type: .single), BusArrival(service: "1", minutes: 28, type: .double)]
        },
        stop: { code in BusStop(code: code, name: "Example Stop", road: "Example Rd") }, // copy-ok: preview data
        searchStops: { _ in [BusStop(code: "00000", name: "Example Stop", road: "Example Rd")] } // copy-ok: preview data
    )
}

extension DependencyValues {
    public var bus: BusClient {
        get { self[BusClient.self] }
        set { self[BusClient.self] = newValue }
    }
}
