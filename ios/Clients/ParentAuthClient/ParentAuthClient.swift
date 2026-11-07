import ComposableArchitecture

/// Unlocks parent mode. Features depend on this interface only; the app target
/// injects the real implementation (`ParentAuthClient.live`) at bootstrap.
@DependencyClient
public struct ParentAuthClient: Sendable {
    /// Returns `true` when the parent proved who they are. Never throws: any failure is `false`.
    public var authenticate: @Sendable (_ reason: String) async -> Bool = { _ in false }
}

extension ParentAuthClient: TestDependencyKey {
    public static let testValue = Self()
}

extension DependencyValues {
    public var parentAuth: ParentAuthClient {
        get { self[ParentAuthClient.self] }
        set { self[ParentAuthClient.self] = newValue }
    }
}
