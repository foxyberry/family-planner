import DesignSystem
import XCTest

/// Boards K1 and K1o (layout v71): the lines inside a month card. On a card the name is 20 in with
/// its baseline 43 down (board: card top 148, "January" baseline 191), the weekday row on 72 (220),
/// the first cell row from 78 (226) on a 30 pitch and 40 across, the seven columns centred (18 in,
/// 18 to spare on the right of 312). Open: 40 in, title baseline 80 (240 − 160), weekdays on 140
/// (300), cells from (40, 148) on 112 across and 104 down.
final class MonthCardLinesTests: XCTestCase {
    func testCardLines() {
        let card = MonthCard.Size.card
        XCTAssertEqual(card.board, CGSize(width: 312, height: 268))
        XCTAssertEqual(card.titleLeft, 20)
        XCTAssertEqual(card.titleBaseline, 43)
        XCTAssertEqual(card.weekdayBaseline, 72)
        XCTAssertEqual(card.gridOrigin, CGPoint(x: 18, y: 78))
        XCTAssertEqual(card.pitch, CGSize(width: 40, height: 30))
        XCTAssertEqual(card.cell.board, CGSize(width: 36, height: 28))
        // Seven columns and six rows fit inside the card.
        XCTAssertEqual(card.gridOrigin.x + 6 * card.pitch.width + card.cell.board.width, 312 - 18)
        XCTAssertLessThanOrEqual(card.gridOrigin.y + 5 * card.pitch.height + card.cell.board.height, 268)
    }

    func testOpenLines() {
        let open = MonthCard.Size.open
        XCTAssertEqual(open.board, CGSize(width: 860, height: 800))
        XCTAssertEqual(open.titleLeft, 40)
        XCTAssertEqual(open.titleBaseline, 80)
        XCTAssertEqual(open.weekdayBaseline, 140)
        XCTAssertEqual(open.gridOrigin, CGPoint(x: 40, y: 148))
        XCTAssertEqual(open.pitch, CGSize(width: 112, height: 104))
        XCTAssertEqual(open.cell.board, CGSize(width: 104, height: 96))
        // Board K1o: "Sun" is centred on x 1022 − 258 = 764 in the card.
        XCTAssertEqual(open.gridOrigin.x + 6 * open.pitch.width + open.cell.board.width / 2, 764, accuracy: 1)
        XCTAssertLessThanOrEqual(open.gridOrigin.y + 5 * open.pitch.height + open.cell.board.height, 800)
    }
}
