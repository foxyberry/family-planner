import DesignSystem
import XCTest

/// Spec "Layout model" relations for `FormLines` on every checked iPad (13", 12.9", 11", mini),
/// with S1's rows (board v51) as the example: Name / Colour, then Age / Face on a second column.
final class FormLinesTests: XCTestCase {
    private let ipads: [(String, Sizing)] = [
        ("13", Sizing(width: 1376, height: 1032)),
        ("12.9", Sizing(width: 1366, height: 1024, safeTop: 32)),
        ("11", Sizing(width: 1180, height: 820)),
        ("mini", Sizing(width: 1133, height: 744)),
    ]

    private func s1(_ sizing: Sizing) -> FormLines {
        GrownupLayout(sizing: sizing).formLines(
            labels: ["Name", "Colour"], secondLabels: ["Age", "Face"],
            secondControlWidth: 2 * sizing.pickedFace + Spacing.sm,
            firstControlMinimum: 4 * ColourSwatch.frame(sizing) + 3 * Spacing.sm)
    }

    /// 13" is board S1 v51: controls on 208, second labels on 606, second controls 678 … 818.
    func testThirteenInchIsTheBoard() throws {
        let sizing = ipads[0].1
        let layout = GrownupLayout(sizing: sizing)
        let lines = s1(sizing)
        let second = try XCTUnwrap(lines.second)
        let left = layout.labelLeft
        XCTAssertEqual(left + lines.width, 818, "rows end on the right-edge line")
        XCTAssertEqual(left + lines.controlX, 208)
        XCTAssertFalse(second.dropsUnder)
        XCTAssertEqual(left + second.controlX, 678)
        XCTAssertEqual(left + second.labelX, 606, accuracy: 2, "Face's measured width + 16")
        XCTAssertEqual(ColourSwatch.frame(sizing), 68, "a 56 circle plus one inset each side")
        XCTAssertEqual(sizing.choiceRowHeight, 72)
        XCTAssertEqual(sizing.fieldRowHeight, 80)
    }

    func testSecondColumnRelationsOnEveryIPad() throws {
        for (name, sizing) in ipads {
            let lines = s1(sizing)
            let second = try XCTUnwrap(lines.second, name)
            XCTAssertEqual(second.controlWidth, 2 * sizing.pickedFace + Spacing.sm, name)
            if second.dropsUnder {
                XCTAssertEqual(second.controlX, lines.controlX, "\(name): dropped controls sit on the control line")
                XCTAssertEqual(lines.firstControlWidth, lines.width - lines.controlX, name)
            } else {
                XCTAssertEqual(second.controlX + second.controlWidth, lines.width, "\(name): ends on the right edge")
                let longest = max(CrayonType.captionBoldWidth("Age"), CrayonType.captionBoldWidth("Face"))
                XCTAssertEqual(second.controlX - second.labelX, longest + 16, accuracy: 0.01, name)
                XCTAssertEqual(lines.controlX + lines.firstControlWidth + 24, second.labelX, accuracy: 0.01,
                               "\(name): the first column stops 24 before the second label")
                XCTAssertGreaterThanOrEqual(lines.firstControlWidth, 4 * ColourSwatch.frame(sizing) + 3 * Spacing.sm,
                                            "\(name): four swatches fit beside the second column")
            }
        }
    }

    func testOneColumnRunsToTheRightEdge() {
        for (name, sizing) in ipads {
            let lines = GrownupLayout(sizing: sizing).formLines(labels: ["Name"])
            XCTAssertNil(lines.second, name)
            XCTAssertEqual(lines.firstControlWidth, lines.width - lines.controlX, name)
        }
    }

    func testTooNarrowDropsTheSecondColumn() throws {
        let sizing = ipads[0].1
        let lines = FormLines(sizing: sizing, width: 400, labels: ["Name"], secondLabels: ["Age"],
                              secondControlWidth: 140, firstControlMinimum: 200)
        let second = try XCTUnwrap(lines.second)
        XCTAssertTrue(second.dropsUnder)
        XCTAssertEqual(second.labelX, 0)
    }
}
