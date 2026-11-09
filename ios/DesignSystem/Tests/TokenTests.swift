import DesignSystem
import XCTest

final class TokenTests: XCTestCase {
    func testGridAtDesignWidth() {
        let grid = GridMetrics(width: 1376)
        XCTAssertEqual(grid.columnWidth, 82, accuracy: 0.001)
        XCTAssertEqual(grid.span(8), 824, accuracy: 0.001)
        XCTAssertEqual(grid.span(4), 400, accuracy: 0.001)
        XCTAssertEqual(grid.x(column: 8), 64 + 8 * (82 + 24), accuracy: 0.001)
    }

    func testGridAtDeviceWidth() {
        let grid = GridMetrics(width: 1366)
        XCTAssertEqual(grid.span(12), 1366 - 128, accuracy: 0.001)
    }

    func testTypeScaleHasSixSteps() {
        XCTAssertEqual(CrayonType.allCases.map(\.size), [144, 96, 48, 36, 30, 24])
    }

    func testNoTextStyleBelow24() {
        XCTAssertTrue(CrayonType.allCases.allSatisfy { $0.size >= 24 })
    }

    func testTextColorsPassContrastOnPaper() {
        let paper = CrayonPalette.paper
        for (name, color) in [
            ("ink", CrayonPalette.ink), ("softText", CrayonPalette.softText),
            ("onTimeText", CrayonPalette.onTimeText), ("lateText", CrayonPalette.lateText),
        ] {
            let ratio = Contrast.ratio(color, paper)
            XCTAssertGreaterThanOrEqual(ratio, 4.5, "\(name) on paper is \(ratio)")
        }
        // Known gap reported to the design owner: the board's link blue measures 4.37 on paper.
        // The colour is kept as designed until they decide; remove this when it is fixed.
        XCTExpectFailure("link #2F6FD0 on paper is 4.37, below 4.5") {
            XCTAssertGreaterThanOrEqual(Contrast.ratio(CrayonPalette.link, paper), 4.5)
        }
        XCTAssertGreaterThanOrEqual(Contrast.ratio(CrayonPalette.nightText, CrayonPalette.night), 7)
        // Spec "Night mapping": soft text 6.2:1, ink on moon paper 9.9:1, labels on night controls;
        // the kid colours ≥ 3:1 (non-text) on the night page and on paper.
        XCTAssertGreaterThanOrEqual(Contrast.ratio(CrayonPalette.nightSoftText, CrayonPalette.night), 6)
        XCTAssertGreaterThanOrEqual(Contrast.ratio(CrayonPalette.ink, CrayonPalette.moonPaper), 9)
        XCTAssertGreaterThanOrEqual(Contrast.ratio(CrayonPalette.nightText, CrayonPalette.nightControl), 7)
        XCTAssertGreaterThanOrEqual(Contrast.ratio(CrayonPalette.kidA, CrayonPalette.night), 3)
        XCTAssertGreaterThanOrEqual(Contrast.ratio(CrayonPalette.kidB, CrayonPalette.night), 3)
    }

    func testContrastKnownValues() {
        XCTAssertEqual(Contrast.ratio(RGB(hex: 0x000000), RGB(hex: 0xFFFFFF)), 21, accuracy: 0.01)
        XCTAssertEqual(Contrast.ratio(CrayonPalette.ink, CrayonPalette.ink), 1, accuracy: 0.0001)
    }

    /// Kids pick a colour by index; more kids than colours wrap around, and a bad index never crashes.
    func testKidColourWrapsAround() {
        let palette = CrayonColor.kidPalette
        XCTAssertEqual(CrayonColor.kid(0), palette[0])
        XCTAssertEqual(CrayonColor.kid(palette.count + 1), palette[1])
        XCTAssertEqual(CrayonColor.kid(-1), palette[palette.count - 1])
    }
}
