import LocalAuthentication
import ParentAuthClient

extension ParentAuthClient {
    /// Face ID only. The device passcode is deliberately not accepted: on a shared family iPad the
    /// children may know it. The system sheet shows no passcode button (`localizedFallbackTitle = ""`).
    public static let live = ParentAuthClient(
        authenticate: { reason in
            let context = LAContext()
            context.localizedFallbackTitle = ""
            var error: NSError?
            guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
                return outcome(for: (error as? LAError)?.code ?? .biometryNotAvailable)
            }
            do {
                _ = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                return .success
            } catch {
                return outcome(for: (error as? LAError)?.code ?? .authenticationFailed)
            }
        },
        biometry: {
            let context = LAContext()
            _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
            switch context.biometryType {
            case .faceID: return .faceID
            case .touchID: return .touchID
            default: return .none
            }
        }
    )

    /// Maps a LocalAuthentication error (or `nil` for success) to what the lock card shows.
    public static func outcome(for code: LAError.Code?) -> ParentAuthOutcome {
        guard let code else { return .success }
        switch code {
        case .authenticationFailed: return .notRecognised
        case .biometryLockout: return .lockedOut
        case .biometryNotEnrolled, .biometryNotAvailable, .passcodeNotSet: return .notAvailable
        default: return .cancelled
        }
    }
}
