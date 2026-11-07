import DesignSystem
import XCTest

final class TimeLeftTests: XCTestCase {
    func testPositiveMinutesUseInk() {
        let p = TimeLeft.presentation(minutes: 19)
        XCTAssertEqual(p.text, "19 min")
        XCTAssertEqual(p.tone, .normal)
    }

    func testZeroOrNegativeUsesLateRed() {
        XCTAssertEqual(TimeLeft.presentation(minutes: 0).tone, .late)
        XCTAssertEqual(TimeLeft.presentation(minutes: -2).tone, .late)
    }

    func testNegativeLabelHasMinusSign() {
        XCTAssertEqual(TimeLeft.presentation(minutes: -2).text, "\u{2212}2 min")
        XCTAssertFalse(TimeLeft.presentation(minutes: -2).text.contains("-"))
    }
}
