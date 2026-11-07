import LocalAuthentication
import ParentAuthClient

extension ParentAuthClient {
    /// Face ID, falling back to the device passcode. Any failure (no Face ID enrolled,
    /// no passcode, user cancelled) is reported as `false`, never thrown.
    public static let live = ParentAuthClient(authenticate: { reason in
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            return false
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    })
}
