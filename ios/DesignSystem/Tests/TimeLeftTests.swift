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
        // Over an hour: "1h 20m" in the same size, so it fits the 384 panel (user, 2026-11-09).
        XCTAssertEqual(TimeLeft.presentation(minutes: 80).text, "1h 20m")
        XCTAssertEqual(TimeLeft.presentation(minutes: 60).text, "60 min")
        XCTAssertEqual(TimeLeft.presentation(minutes: 120).text, "2h")
    }

    func testNegativeLabelHasMinusSign() {
        XCTAssertEqual(TimeLeft.presentation(minutes: -2).text, "\u{2212}2 min")
        XCTAssertFalse(TimeLeft.presentation(minutes: -2).text.contains("-"))
    }

    func testSpokenTimesUseFullWords() {
        XCTAssertEqual(TimeLeft.spoken(minutes: 38), "38 minutes")
        XCTAssertEqual(TimeLeft.spoken(minutes: 1), "1 minute")
        XCTAssertEqual(TimeLeft.spoken(minutes: 80), "1 hour 20 minutes")
        XCTAssertEqual(TimeLeft.spoken(minutes: 120), "2 hours")
        XCTAssertEqual(TimeLeft.spoken(minutes: -2), "2 minutes late")
    }
}
