import DesignSystem
import SchoolYear
import XCTest

/// Boards K1 and K1o (layout v82): the school calendar's parts at s = 1, and the board × s on every
/// iPad (spec "Sizing: one scale, no floors").
final class SchoolYearLayoutTests: XCTestCase {
    private let iPads = [Sizing(width: 1366, height: 1024), Sizing(width: 1180, height: 820),
                         Sizing(width: 1133, height: 744), Sizing(width: 890, height: 626)]

    func testThirteenInchIsTheBoard() {
        let layout = SchoolYearLayout(sizing: .thirteenInch)
        XCTAssertEqual(layout.back, CGRect(x: 40, y: 44, width: 80, height: 80))
        XCTAssertEqual(layout.tabs, CGPoint(x: 144, y: 48), "tabs 150 × 72 on the header's middle")
        XCTAssertEqual(layout.legend, CGRect(x: 480, y: 44, width: 856, height: 80))
        XCTAssertEqual(layout.card(0), CGRect(x: 40, y: 148, width: 312, height: 268))
        // Board K1: February's name at 388 = card 1 at 368 + 20; April's at 1044 = 1024 + 20.
        XCTAssertEqual(layout.card(1).minX, 368)
        XCTAssertEqual(layout.card(3).minX, 1024)
        XCTAssertEqual(layout.card(3).maxX, 1336, "the right margin is 40")
        XCTAssertEqual(layout.card(4).minY, 148 + 268 + 12)
        XCTAssertEqual(layout.card(11).maxY, 976)
        // Layout v82: the open month 1200 × 800 at (88, 160); its names column at x 928 (840 in), 320
        // wide, ends 40 inside the card's right edge.
        XCTAssertEqual(layout.openCard, CGRect(x: 88, y: 160, width: 1200, height: 800))
        XCTAssertEqual(layout.openClose, CGRect(x: 1176, y: 184, width: 72, height: 72))
        XCTAssertEqual(layout.openCard.minX + MonthCard.Size.open.names.minX, 928)
        XCTAssertEqual(layout.openCard.maxX - (layout.openCard.minX + MonthCard.Size.open.names.maxX), 40)
        // The tabs end before the legend starts.
        let tabsRight = layout.tabs.x + 2 * SchoolYearLayout.tabSize.width + SchoolYearLayout.tabGap
        XCTAssertLessThan(tabsRight, layout.legend.minX)
    }

    func testEveryPartIsTheBoardTimesS() {
        let rects = { (l: SchoolYearLayout) in
            [l.back, l.legend, l.openCard, l.openClose] + (0..<12).map(l.card)
        }
        let board = rects(SchoolYearLayout(sizing: .thirteenInch))
        for sizing in iPads {
            for (a, b) in zip(rects(SchoolYearLayout(sizing: sizing)), board) {
                XCTAssertEqual(a.minX, b.minX * sizing.s, accuracy: 0.01, "\(sizing.window)")
                XCTAssertEqual(a.minY, sizing.y(b.minY), accuracy: 0.01, "\(sizing.window)")
                XCTAssertEqual(a.width, b.width * sizing.s, accuracy: 0.01, "\(sizing.window)")
                XCTAssertEqual(a.height, b.height * sizing.s, accuracy: 0.01, "\(sizing.window)")
            }
            // The last card stays on the window.
            XCTAssertLessThanOrEqual(SchoolYearLayout(sizing: sizing).card(11).maxY, sizing.height, "\(sizing.window)")
        }
    }
}
