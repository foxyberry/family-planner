import XCTest

/// S1 by hand: what the journeys can't show is the keyboard moving between fields.
@MainActor
final class SetupUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// Typing a name, then an age, keeps the name: the field sends its text again when it loses
    /// focus. A face then turns Next on.
    func testTypingANameAndAnAgeTurnsNextOn() {
        let app = TestApp.launch(family: "empty")
        let next = app.buttons["Next"]
        XCTAssertTrue(next.waitForExistence(timeout: 20))
        XCTAssertFalse(next.isEnabled)

        let name = app.textFields.element(boundBy: 0)
        type("Kid A", into: name)
        let age = app.textFields.element(boundBy: 1)
        type("8", into: age)
        app.buttons["kidGirl"].tap()

        XCTAssertEqual(name.value as? String, "Kid A")
        XCTAssertEqual(age.value as? String, "8")
        XCTAssertTrue(next.isEnabled)
    }

    /// Taps the field and waits for the keyboard to reach it (it can still be moving off the last one).
    private func type(_ text: String, into field: XCUIElement) {
        field.tap()
        let focused = expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)
        wait(for: [focused], timeout: 5)
        field.typeText(text)
    }
}
