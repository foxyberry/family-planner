import DesignSystem
import XCTest

/// Spec "Layout model" and "Layout balance" relations for `FormLines` on every checked iPad (13",
/// 12.9", 11", mini), with S1's rows (board v55) as the example: Name / Colour, then Age / Face on a
/// second column. Gaps are drawn-edge gaps: a crayon part draws 6 inside its frame.
final class FormLinesTests: XCTestCase {
    private let ipads: [(String, Sizing)] = [
        ("13", Sizing(width: 1376, height: 1032)),
        ("12.9", Sizing(width: 1366, height: 1024, safeTop: 32)),
        ("11", Sizing(width: 1180, height: 820)),
        ("mini", Sizing(width: 1133, height: 744)),
    ]
    private let inset = CrayonPart.inset

    private func s1(_ sizing: Sizing) -> FormLines {
        GrownupLayout(sizing: sizing).formLines(
            secondLabels: ["Age", "Face"],
            secondControlWidth: 2 * sizing.pickedFace + Spacing.sm,
            firstControlMinimum: 4 * ColourSwatch.frame(sizing) + 3 * Spacing.sm)
    }

    /// S1's card height from its rows: padding, the Name row's drawn box, the row gap, the Colour /
    /// Face row's drawn box, padding.
    private func s1CardHeight(_ sizing: Sizing) -> CGFloat {
        FormLines.cardPadding.top + sizing.fieldRowHeight - 2 * inset + sizing.formRowGap
            + max(sizing.pickedFace, sizing.swatch) + FormLines.cardPadding.bottom
    }

    /// 13" is board S1 v55: labels 78, controls 192, Name 192–568, second labels 602, Age and faces
    /// 668–808, cards 232 tall and 28 apart (148, 408).
    func testThirteenInchIsTheBoard() throws {
        let sizing = ipads[0].1
        let layout = GrownupLayout(sizing: sizing)
        let lines = s1(sizing)
        let second = try XCTUnwrap(lines.second)
        let left = layout.form.minX + FormLines.cardPadding.leading
        XCTAssertEqual(left, 78, "label line = card drawn edge + 32")
        XCTAssertEqual(left + lines.width, 808, "rows end on the right-edge line")
        XCTAssertEqual(left + lines.controlX, 192)
        XCTAssertFalse(second.dropsUnder)
        XCTAssertEqual(left + second.controlX, 668)
        XCTAssertEqual(second.controlWidth, 140)
        XCTAssertEqual(left + second.labelX, 602, accuracy: 2, "Face's measured width + 10")
        XCTAssertEqual(left + lines.controlX + lines.firstControlWidth, 568, accuracy: 2, "Name ends 40 drawn before Age")
        XCTAssertEqual(ColourSwatch.frame(sizing), 68, "a 56 circle plus one inset each side")
        XCTAssertEqual(sizing.choiceRowHeight, 68)
        XCTAssertEqual(sizing.fieldRowHeight, 80)
        XCTAssertEqual(sizing.formRowGap, 24)
        XCTAssertEqual(s1CardHeight(sizing), 232)
        XCTAssertEqual(layout.form.minY + s1CardHeight(sizing) + FormLines.cardGap, 408, "the second card's top")
    }

    func testSecondColumnRelationsOnEveryIPad() throws {
        for (name, sizing) in ipads {
            let lines = s1(sizing)
            let second = try XCTUnwrap(lines.second, name)
            XCTAssertEqual(lines.controlX, 114, "\(name): one fixed label column")
            XCTAssertEqual(second.controlWidth, 2 * sizing.pickedFace + Spacing.sm, name)
            XCTAssertFalse(second.dropsUnder, "\(name): S1's second column stands beside the first down to the mini")
            XCTAssertEqual(second.controlX + second.controlWidth, lines.width, "\(name): ends on the right edge")
            let longest = max(CrayonType.captionBoldWidth("Age"), CrayonType.captionBoldWidth("Face"))
            XCTAssertEqual(second.controlX - second.labelX, longest + 10, accuracy: 0.01, name)
            XCTAssertEqual(second.labelX - (lines.controlX + lines.firstControlWidth - inset), 40, accuracy: 0.01,
                           "\(name): the first column's drawn end stops 40 before the second label")
            XCTAssertGreaterThanOrEqual(lines.firstControlWidth, 4 * ColourSwatch.frame(sizing) + 3 * Spacing.sm,
                                        "\(name): four swatches fit beside the second column")
            XCTAssertGreaterThanOrEqual(sizing.formRowGap, 16, "\(name): rows stay further apart than label → control")
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
        let lines = FormLines(width: 400, secondLabels: ["Age"], secondControlWidth: 140, firstControlMinimum: 100)
        let second = try XCTUnwrap(lines.second)
        XCTAssertTrue(second.dropsUnder)
        XCTAssertEqual(second.labelX, 0)
        XCTAssertEqual(lines.firstControlWidth, lines.width - lines.controlX)
    }
}
