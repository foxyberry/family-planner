import XCTest

/// Board C0 by hand: the real 2 s hold on the clock. Journeys start after it (`clockHoldCompleted`).
@MainActor
final class LockUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func home() -> (XCUIApplication, clock: XCUIElement, missions: XCUIElement) {
        let app = TestApp.launch(family: "sample")
        let missions = app.buttons["Missions"]
        XCTAssertTrue(missions.waitForExistence(timeout: 20), "the kids' home")
        // The clock face: Kid A's "School" sits at its centre at 7:30 on a school day.
        return (app, app.staticTexts["School"], missions)
    }

    func testAShortPressOnTheClockDoesNothing() {
        let (_, clock, missions) = home()
        clock.press(forDuration: 0.5)
        sleep(3)
        XCTAssertTrue(missions.exists, "still on the home")
    }

    /// Face ID is skipped (`-fpSkipFaceID`), so the hold alone opens Our day.
    func testHoldingTheClockTwoSecondsOpensOurDay() {
        let (app, clock, missions) = home()
        clock.press(forDuration: 2.5)
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: missions)
        wait(for: [gone], timeout: 10)
        XCTAssertTrue(app.staticTexts["Our day"].exists)
        XCTAssertTrue(app.buttons["Settings"].exists)
    }
}
