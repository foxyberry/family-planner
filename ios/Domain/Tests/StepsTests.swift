import Domain
import XCTest

/// Steppers' limits: the reducer clamps to them, and an end the value sits on turns its − or + off.
final class StepsTests: XCTestCase {
    func testClampKeepsTheValueInItsLimits() {
        XCTAssertEqual(StepRange.walk.clamp(-1), 0)
        XCTAssertEqual(StepRange.walk.clamp(61), 60)
        XCTAssertEqual(StepRange.times.clamp(0), 1)
        XCTAssertEqual(StepRange.ride.clamp(45), 45)
    }

    func testAnEndAtItsLimitIsOff() {
        XCTAssertEqual(StepRange.leave.ends(0), StepEnds(canLower: false, canRaise: true))
        XCTAssertEqual(StepRange.leave.ends(45), StepEnds(canLower: true, canRaise: true))
        XCTAssertEqual(StepRange.leave.ends(90), StepEnds(canLower: true, canRaise: false))
        XCTAssertEqual(StepRange.times.ends(1), StepEnds(canLower: false, canRaise: true))
        XCTAssertEqual(StepRange.lateGrace.ends(30), StepEnds(canLower: true, canRaise: false))
    }
}
