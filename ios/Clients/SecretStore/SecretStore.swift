import ComposableArchitecture

/// Small secrets that must never reach the repo or the store file (the LTA key). The live value
/// keeps them in the Keychain on this iPad.
@DependencyClient
public struct SecretStore: Sendable {
    public var read: @Sendable (_ name: SecretName) async -> String? = { _ in nil }
    /// Saves `value`, or removes the secret when it is nil.
    public var write: @Sendable (_ name: SecretName, _ value: String?) async throws -> Void
}

public enum SecretName: String, Sendable, CaseIterable {
    case busKey = "lta-datamall-key" // copy-ok: keychain account name
}

extension SecretStore: TestDependencyKey {
    public static let testValue = Self()
    public static let previewValue = Self.inMemory()

    /// A store that forgets everything when the app quits (previews, tests).
    public static func inMemory(_ start: [SecretName: String] = [:]) -> Self {
        let values = LockIsolated(start)
        return Self(read: { values.value[$0] }, write: { name, value in values.withValue { $0[name] = value } })
    }
}

extension DependencyValues {
    public var secrets: SecretStore {
        get { self[SecretStore.self] }
        set { self[SecretStore.self] = newValue }
    }
}
