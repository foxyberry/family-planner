import DesignSystem
import XCTest

final class ContentLogicTests: XCTestCase {
    func testLeagueProgressNeverExceedsGoal() {
        XCTAssertEqual(LeagueProgress.fraction(done: 18, goal: 30), 0.6, accuracy: 0.0001)
        XCTAssertEqual(LeagueProgress.fraction(done: 40, goal: 30), 1.0)
        XCTAssertEqual(LeagueProgress.fraction(done: 0, goal: 0), 1.0)
    }

    func testLeagueRemainingText() {
        XCTAssertEqual(LeagueProgress.remainingText(done: 18, goal: 30, nextName: "Double-Decker"),
                       "12 more Go! days to the Double-Decker")
        XCTAssertEqual(LeagueProgress.remainingText(done: 29, goal: 30, nextName: "Double-Decker"),
                       "1 more Go! day to the Double-Decker")
    }
}
