import LocalAuthentication
import ParentAuthClient
import ParentAuthClientLive
import XCTest

final class ParentAuthOutcomeTests: XCTestCase {
    func testOutcomeMapping() {
        XCTAssertEqual(ParentAuthClient.outcome(for: nil), .success)
        XCTAssertEqual(ParentAuthClient.outcome(for: .authenticationFailed), .notRecognised)
        for code: LAError.Code in [.userCancel, .systemCancel, .appCancel, .userFallback] {
            XCTAssertEqual(ParentAuthClient.outcome(for: code), .cancelled, "\(code)")
        }
        for code: LAError.Code in [.biometryNotEnrolled, .biometryNotAvailable, .passcodeNotSet] {
            XCTAssertEqual(ParentAuthClient.outcome(for: code), .notAvailable, "\(code)")
        }
        XCTAssertEqual(ParentAuthClient.outcome(for: .biometryLockout), .lockedOut)
    }
}
