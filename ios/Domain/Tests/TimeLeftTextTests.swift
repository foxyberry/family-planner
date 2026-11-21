import Domain
import XCTest

final class TimeLeftTextTests: XCTestCase {
    func testPositiveMinutesUseInk() {
        XCTAssertEqual(TimeLeftText.short(minutes: 19), "19 min")
        XCTAssertFalse(TimeLeftText.isLate(minutes: 19))
    }

    func testZeroOrNegativeUsesLateRed() {
        XCTAssertTrue(TimeLeftText.isLate(minutes: 0))
        XCTAssertTrue(TimeLeftText.isLate(minutes: -2))
        // Over an hour: "1h 20m" in the same size, so it fits the 384 panel (user, 2026-11-09).
        XCTAssertEqual(TimeLeftText.short(minutes: 80), "1h 20m")
        XCTAssertEqual(TimeLeftText.short(minutes: 60), "60 min")
        XCTAssertEqual(TimeLeftText.short(minutes: 120), "2h")
    }

    func testNegativeLabelHasMinusSign() {
        XCTAssertEqual(TimeLeftText.short(minutes: -2), "\u{2212}2 min")
        XCTAssertFalse(TimeLeftText.short(minutes: -2).contains("-"))
    }

    func testSpokenTimesUseFullWords() {
        XCTAssertEqual(TimeLeftText.spoken(minutes: 38), "38 minutes")
        XCTAssertEqual(TimeLeftText.spoken(minutes: 1), "1 minute")
        XCTAssertEqual(TimeLeftText.spoken(minutes: 80), "1 hour 20 minutes")
        XCTAssertEqual(TimeLeftText.spoken(minutes: 120), "2 hours")
        XCTAssertEqual(TimeLeftText.spoken(minutes: -2), "2 minutes late")
    }
}
