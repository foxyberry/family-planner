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
        // Over an hour: "1 h 20 min" in the same size.
        XCTAssertEqual(TimeLeft.presentation(minutes: 80).text, "1 h 20 min")
        XCTAssertEqual(TimeLeft.presentation(minutes: 60).text, "60 min")
        XCTAssertEqual(TimeLeft.presentation(minutes: 120).text, "2 h")
    }

    func testNegativeLabelHasMinusSign() {
        XCTAssertEqual(TimeLeft.presentation(minutes: -2).text, "\u{2212}2 min")
        XCTAssertFalse(TimeLeft.presentation(minutes: -2).text.contains("-"))
    }
}
