import DesignSystem
import XCTest

/// Spec "Layout balance" (layout 3b: C2, C2c, S2, S3, S4): rows sit `formRowGap` apart between drawn
/// edges on every iPad, so a row's frame follows its parts' scaled height, never the 13" board's.
@MainActor
final class FormRhythmTests: XCTestCase {
    private let iPads = [Sizing(width: 1376, height: 1032), Sizing(width: 1366, height: 1024),
                         Sizing(width: 1180, height: 820), Sizing(width: 1133, height: 744)]

    func testRowsFollowTheirScaledParts() {
        for sizing in iPads {
            let w = sizing.width
            // A stepper row is as tall as its buttons, which scale to a 56 floor.
            XCTAssertEqual(MinutesStepper.rowHeight(sizing), sizing.roundButton(72), "\(w)")
            XCTAssertGreaterThanOrEqual(MinutesStepper.rowHeight(sizing), 56, "\(w)")
            XCTAssertLessThanOrEqual(MinutesStepper.rowHeight(sizing), 72, "\(w)")
            // Pills and tabs, fields: their rows use the same scaled heights.
            XCTAssertEqual(sizing.tabHeight(), max(72 * sizing.s, 56), accuracy: 0.01, "\(w)")
            XCTAssertEqual(sizing.fieldHeight, max(80 * sizing.s, 64), accuracy: 0.01, "\(w)")
            // Rows 24 apart (drawn) on the 13", never under 16 on smaller iPads.
            XCTAssertGreaterThanOrEqual(sizing.formRowGap, 16, "\(w)")
            XCTAssertLessThanOrEqual(sizing.formRowGap, 24, "\(w)")
            // The stepper's value column keeps "90 min" bold.
            XCTAssertGreaterThanOrEqual(sizing.stepperValueWidth, 112, "\(w)")
        }
    }

    func testThirteenInchIsTheBoard() {
        let sizing = Sizing(width: 1376, height: 1032)
        XCTAssertEqual(sizing.formRowGap, 24)
        XCTAssertEqual(MinutesStepper.rowHeight(sizing), 72)
        XCTAssertEqual(sizing.stepperValueWidth, 144)
        // A caption sits 8 under its field's drawn edge: 2 under the frame (inset 6).
        XCTAssertEqual(FormLines.captionGap + CrayonPart.inset, 8)
        // The first row's drawn top is the card's padding: 148 + 38 = 186 on the board.
        XCTAssertEqual(148 + FormLines.cardPadding.top, 186)
    }
}
