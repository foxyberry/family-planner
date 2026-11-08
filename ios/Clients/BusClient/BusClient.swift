import ComposableArchitecture
import Domain

/// Live bus times (LTA DataMall). Features use this interface; the app injects the live one.
/// The key is passed in from the secret store, so it never sits in this module.
@DependencyClient
public struct BusClient: Sendable {
    /// Arrivals at `stop` now: up to three per bus number, minutes from now.
    public var arrivals: @Sendable (_ stop: String, _ key: String) async throws -> [BusArrival]
    /// The stop's name for the C2 confirm ("Opp Blk 123" style), or nil for an unknown code.
    public var stopName: @Sendable (_ stop: String, _ key: String) async throws -> String?
}

extension BusClient: TestDependencyKey {
    public static let testValue = Self()
    /// Made-up arrivals for previews (privacy rule: no real stops or buses).
    public static let previewValue = Self(
        arrivals: { _, _ in
            [BusArrival(service: "1", minutes: 4, type: .single), BusArrival(service: "1", minutes: 28, type: .double)]
        },
        stopName: { _, _ in "Example Stop" } // copy-ok: preview data
    )
}

extension DependencyValues {
    public var bus: BusClient {
        get { self[BusClient.self] }
        set { self[BusClient.self] = newValue }
    }
}
