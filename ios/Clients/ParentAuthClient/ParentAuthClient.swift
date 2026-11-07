import ComposableArchitecture

/// What happened when a parent tried to unlock grown-up screens.
public enum ParentAuthOutcome: Equatable, Sendable {
    case success
    /// The system gave up recognising the face.
    case notRecognised
    /// The parent or the system closed the sheet.
    case cancelled
    /// Face ID (or Touch ID) is not set up or not available on this iPad.
    case notAvailable
    /// Too many tries; the iPad must be unlocked with its passcode first.
    case lockedOut
}

public enum Biometry: Equatable, Sendable {
    case faceID, touchID, none
}

/// Unlocks parent mode with Face ID only. Features depend on this interface only; the app target
/// injects the real implementation (`ParentAuthClient.live`) at bootstrap.
@DependencyClient
public struct ParentAuthClient: Sendable {
    public var authenticate: @Sendable (_ reason: String) async -> ParentAuthOutcome = { _ in .notAvailable }
    /// Which sensor this iPad has, for the wording of the lock card.
    public var biometry: @Sendable () -> Biometry = { .none }
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
