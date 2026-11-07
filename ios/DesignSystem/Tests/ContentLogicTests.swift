import DesignSystem
import XCTest

final class ContentLogicTests: XCTestCase {
    func testCrowdFaces() {
        XCTAssertEqual(Crowd.seats.happyFaces, 2)
        XCTAssertEqual(Crowd.standing.happyFaces, 1)
        XCTAssertEqual(Crowd.full.happyFaces, 0)
    }

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

    func testBusPlateSizes() {
        XCTAssertEqual(BusBubble.plateFontSize(isMine: true), 28)
        XCTAssertEqual(BusBubble.plateFontSize(isMine: false), 24)
        XCTAssertGreaterThanOrEqual(BusBubble.plateFontSize(isMine: false), CrayonType.caption.size)
    }
}
