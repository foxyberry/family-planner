import DesignSystem
import XCTest

final class ContentLogicTests: XCTestCase {
    func testLeagueProgressNeverExceedsGoal() {
        XCTAssertEqual(LeagueProgress.fraction(done: 18, goal: 30), 0.6, accuracy: 0.0001)
        XCTAssertEqual(LeagueProgress.fraction(done: 40, goal: 30), 1.0)
        XCTAssertEqual(LeagueProgress.fraction(done: 0, goal: 0), 1.0)
    }
}
