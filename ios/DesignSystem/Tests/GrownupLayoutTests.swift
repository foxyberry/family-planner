import DesignSystem
import XCTest

/// The grown-up boards' shared lines hold on every iPad (layout v4, README "Grown-up").
final class GrownupLayoutTests: XCTestCase {
    private let windows = [Sizing(width: 1376, height: 1032), Sizing(width: 1366, height: 1024, safeTop: 32),
                           Sizing(width: 1180, height: 820), Sizing(width: 1133, height: 744),
                           Sizing(width: 890, height: 626)]

    /// A 13" rect on `sizing`: x and sizes × s, y from the safe top.
    private func scaled(_ rect: CGRect, _ sizing: Sizing) -> CGRect {
        CGRect(x: rect.minX * sizing.s, y: sizing.y(rect.minY), width: rect.width * sizing.s,
               height: rect.height * sizing.s)
    }

    private func assertEqual(_ a: CGRect, _ b: CGRect, _ message: String) {
        XCTAssertEqual(a.minX, b.minX, accuracy: 0.01, message)
        XCTAssertEqual(a.minY, b.minY, accuracy: 0.01, message)
        XCTAssertEqual(a.width, b.width, accuracy: 0.01, message)
        XCTAssertEqual(a.height, b.height, accuracy: 0.01, message)
    }

    /// Spec "Sizing: one scale, no floors": every line is the board's × s, so the shared lines hold on
    /// every window by themselves.
    func testEveryLineIsTheBoardTimesS() {
        let board = GrownupLayout(sizing: .thirteenInch)
        for sizing in windows {
            let layout = GrownupLayout(sizing: sizing), s = sizing.s, w = "\(sizing.window.width)"
            for (a, b) in [(layout.back, board.back), (layout.form, board.form), (layout.side, board.side),
                           (layout.action, board.action)] {
                assertEqual(a, scaled(b, sizing), w)
            }
            for (a, b) in [(layout.labelLeft, board.labelLeft), (layout.controlLeft, board.controlLeft),
                           (layout.rightEdge, board.rightEdge), (layout.right, board.right),
                           (layout.valueLeft, board.valueLeft)] {
                XCTAssertEqual(a, b * s, accuracy: 0.01, w)
            }
            XCTAssertEqual(layout.gap, 24 * s, accuracy: 0.01, w)
            XCTAssertEqual(layout.headerBaseline, sizing.y(103), accuracy: 0.01, w)
            XCTAssertEqual(layout.action.maxY, sizing.y(968), accuracy: 0.01, w)
            XCTAssertGreaterThanOrEqual(layout.back.minY, Sizing.statusBand, w)
            // The board fits the window: nothing is cropped and nothing scrolls because of it.
            XCTAssertLessThanOrEqual(layout.right + 40 * s, sizing.width + 0.01, w)
            XCTAssertLessThanOrEqual(sizing.width, sizing.window.width + 0.01, w)
            XCTAssertLessThanOrEqual(layout.action.maxY, sizing.height, w)
        }
    }

    func testThirteenInchIsTheBoard() {
        let layout = GrownupLayout(sizing: Sizing(width: 1376, height: 1032))
        XCTAssertEqual(layout.back, CGRect(x: 40, y: 44, width: 80, height: 80))
        XCTAssertEqual(layout.form, CGRect(x: 40, y: 148, width: 800, height: 820))
        XCTAssertEqual(layout.contentTop, 148)
        XCTAssertEqual(layout.headerBaseline, 103)
        XCTAssertEqual(layout.side.minX, 864)
        XCTAssertEqual(layout.side.width, 472)
        XCTAssertEqual(layout.action, CGRect(x: 864, y: 872, width: 472, height: 96))
        XCTAssertEqual(layout.labelLeft, 78)
        XCTAssertEqual(layout.controlLeft, 192)
        XCTAssertEqual(layout.valueLeft, 256)
        XCTAssertEqual(layout.gap, 24)
        // Layout v56: every form's rows run 78 … 808 (drawn 802).
        XCTAssertEqual(layout.rightEdge, 808)
        XCTAssertEqual(layout.editorRowsWidth, 730)
        XCTAssertEqual(layout.controlWidth, 616)
    }

    /// Board C3k: with the keyboard open (top at 612) the form card and the button end 28 above it;
    /// the header, the card's top and the side column's top stay.
    func testTheKeyboardShrinksTheCardAndLiftsTheButton() {
        let open = GrownupLayout(sizing: Sizing(width: 1376, height: 1032), keyboardTop: 612)
        XCTAssertEqual(open.back, CGRect(x: 40, y: 44, width: 80, height: 80))
        XCTAssertEqual(open.form, CGRect(x: 40, y: 148, width: 800, height: 436))
        XCTAssertEqual(open.action, CGRect(x: 864, y: 488, width: 472, height: 96))
        XCTAssertEqual(open.side.minY, 148)
    }
}
