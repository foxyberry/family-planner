import DesignSystem
import XCTest

/// Spec "Layout model" and "Layout balance" relations for `FormLines` at s = 1 and on smaller
/// windows (12.9", 11", mini, the Duo inner screen), with S1's rows (board v56) as the example: Name / Colour, then Age / Face on a
/// second column. Gaps are drawn-edge gaps: a crayon part draws 6 inside its frame.
final class FormLinesTests: XCTestCase {
    private let ipads: [(String, Sizing)] = [
        ("13", Sizing(width: 1376, height: 1032)),
        ("12.9", Sizing(width: 1366, height: 1024, safeTop: 32)),
        ("11", Sizing(width: 1180, height: 820)),
        ("mini", Sizing(width: 1133, height: 744)),
        ("duo", Sizing(width: 890, height: 626)),
    ]

    private func s1(_ sizing: Sizing) -> FormLines {
        GrownupLayout(sizing: sizing).formLines(
            secondLabels: ["Age", "Face"],
            secondControlWidth: 2 * sizing.pickedFace + sizing(Spacing.sm),
            firstControlMinimum: 4 * ColourSwatch.frame(sizing) + 3 * sizing(Spacing.sm))
    }

    /// S1's card height from its rows: padding, the Name row's drawn box, the row gap, the Colour /
    /// Face row's drawn box, padding.
    private func s1CardHeight(_ sizing: Sizing) -> CGFloat {
        sizing.cardPadding.top + sizing.fieldRowHeight - 2 * sizing.inset + sizing.formRowGap
            + max(sizing.pickedFace, sizing.swatch) + sizing.cardPadding.bottom
    }

    /// 13" is board S1 v56: labels 78, controls 192, Name 192–556, second labels 590, the second
    /// column frame 656–808 (drawn 662–802), cards 232 tall and 28 apart (148, 408).
    func testThirteenInchIsTheBoard() throws {
        let sizing = ipads[0].1
        let layout = GrownupLayout(sizing: sizing)
        let lines = s1(sizing)
        let second = try XCTUnwrap(lines.second)
        let left = layout.form.minX + sizing.cardPadding.leading
        XCTAssertEqual(left, 78, "label line = card drawn edge + 32")
        XCTAssertEqual(left + lines.width, 808, "rows end on the right-edge line")
        XCTAssertEqual(left + lines.controlX, 192)
        XCTAssertFalse(second.dropsUnder)
        XCTAssertEqual(left + second.controlX, 656)
        XCTAssertEqual(second.controlWidth, 152, "drawn 140 + one inset each side")
        XCTAssertEqual(left + second.labelX, 590, accuracy: 2, "Face's measured width + 10")
        XCTAssertEqual(left + lines.controlX + lines.firstControlWidth, 556, accuracy: 2, "Name ends 40 drawn before Age")
        XCTAssertEqual(ColourSwatch.frame(sizing), 68, "a 56 circle plus one inset each side")
        XCTAssertEqual(sizing.choiceRowHeight, 76, "a 64 face in one inset each side")
        XCTAssertEqual(sizing.fieldRowHeight, 80)
        XCTAssertEqual(sizing.formRowGap, 24)
        XCTAssertEqual(s1CardHeight(sizing), 232)
        XCTAssertEqual(layout.form.minY + s1CardHeight(sizing) + sizing.cardGap, 408, "the second card's top")
    }

    /// Every line is the 13" line × s, so the second column never drops on a smaller window.
    func testSecondColumnScalesWithS() throws {
        let board = try XCTUnwrap(s1(ipads[0].1).second)
        for (name, sizing) in ipads {
            let lines = s1(sizing), s = sizing.s
            let second = try XCTUnwrap(lines.second, name)
            XCTAssertEqual(lines.controlX, 114 * s, accuracy: 0.01, "\(name): one label column × s")
            XCTAssertFalse(second.dropsUnder, "\(name): S1's second column stands beside the first")
            XCTAssertEqual(second.labelX, board.labelX * s, accuracy: 0.01, name)
            XCTAssertEqual(second.controlX, board.controlX * s, accuracy: 0.01, name)
            XCTAssertEqual(second.controlWidth, board.controlWidth * s, accuracy: 0.01, name)
            XCTAssertEqual(second.controlX + second.controlWidth, lines.width, accuracy: 0.01, "\(name): ends on the right edge")
            XCTAssertEqual(second.labelX - (lines.controlX + lines.firstControlWidth - sizing.inset), 40 * s,
                           accuracy: 0.01, "\(name): the first column's drawn end stops 40 × s before the second label")
            XCTAssertEqual(s1CardHeight(sizing), 232 * s, accuracy: 0.01, name)
        }
    }

    /// Spec "Label column": every first-column label fits 104 at caption 24 bold.
    func testLabelsFitTheColumn() {
        for label in ["Name", "Colour", "Off days", "Arrive"] {
            XCTAssertLessThanOrEqual(CrayonType.captionBoldWidth(label), FormLines.labelMaximum, label)
        }
    }

    func testOneColumnRunsToTheRightEdge() {
        for (name, sizing) in ipads {
            let lines = GrownupLayout(sizing: sizing).formLines()
            XCTAssertNil(lines.second, name)
            XCTAssertEqual(lines.firstControlWidth, lines.width - lines.controlX, name)
        }
    }

    func testTooNarrowDropsTheSecondColumn() throws {
        let lines = FormLines(sizing: .thirteenInch, width: 400, secondLabels: ["Age"], secondControlWidth: 140,
                              firstControlMinimum: 100)
        let second = try XCTUnwrap(lines.second)
        XCTAssertTrue(second.dropsUnder)
        XCTAssertEqual(second.labelX, 0)
        XCTAssertEqual(lines.firstControlWidth, lines.width - lines.controlX)
    }

    /// Layout v56 board C3x: "Leave" / "Keep editing" gives a 541 card on the 13" (drawn content +
    /// 64, frame + 12); a short choice keeps the 520 board width; × s elsewhere.
    func testConfirmCardWidth() {
        let sizing = ipads[0].1
        XCTAssertEqual(ConfirmCard.width(sizing: sizing, cancel: "Keep editing"), 541, accuracy: 1)
        XCTAssertEqual(ConfirmCard.width(sizing: sizing, cancel: "Keep"), 532, "520 drawn + 12")
    }
}
