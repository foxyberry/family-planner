import LocalAuthentication
import ParentAuthClient

extension ParentAuthClient {
    /// Face ID only. The device passcode is deliberately not accepted: on a shared family iPad
    /// the children may know it. A separate parent PIN fallback arrives with parent settings (M1).
    /// Any failure (no Face ID enrolled, face not matched, cancelled) is `false`, never thrown.
    public static let live = ParentAuthClient(authenticate: { reason in
        let context = LAContext()
        context.localizedFallbackTitle = ""  // hide the "Enter Passcode" button
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch {
            return false
        }
    })
}
