import DesignSystem
import Home
import XCTest

/// Boards A1, A1m, A1n, E1, E3: the panel's lines hold on every iPad, and nothing leaves the panel.
final class HomeLayoutTests: XCTestCase {
    private let iPads = [Sizing(width: 1376, height: 1032), Sizing(width: 1366, height: 1024),
                         Sizing(width: 1180, height: 820), Sizing(width: 1133, height: 744)]

    func testPanelLinesOnEveryIPad() {
        for sizing in iPads {
            let layout = HomeLayout(sizing: sizing), w = sizing.width
            // x 928: badges, rows, now circle and the button start on the panel's left line.
            let lefts = [layout.kidBadge(top: layout.kidATop).minX, layout.nextRow.picture.minX,
                         layout.timeLeftRow.picture.minX, layout.leaveNextRow.picture.minX,
                         layout.nowNext(kidBTop: 442).x, layout.button.minX]
            for left in lefts {
                XCTAssertEqual(left, layout.panelLeft, accuracy: 0.01, "\(w)")
            }
            // x 1312: the way picture and the button end on the panel's right line.
            XCTAssertEqual(layout.way.maxX, layout.panelRight, accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.button.maxX, layout.panelRight, accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.panelRight, w - 64 * sizing.s, accuracy: 0.01, "\(w)")
            // Each row's text starts 24 right of its picture.
            for row in [layout.nextRow, layout.timeLeftRow, layout.leaveNextRow] {
                XCTAssertEqual(row.textLeft, row.picture.maxX + 24 * sizing.s, accuracy: 0.01, "\(w)")
            }
            // The button ends on 968; the sky switch stays below the status band.
            XCTAssertEqual(layout.button.maxY, sizing.y(968), accuracy: 0.01, "\(w)")
            XCTAssertGreaterThanOrEqual(layout.skySwitch.minY, Sizing.statusBand, "\(w)")
        }
    }

    /// Kid B starts 64 below Kid A's last part on every shape (A1 529, A1m 475, A1n 569, E3 442), and
    /// its now / next row (160 + caption) stays above the button.
    func testKidBStartsUnderKidAsBlock() {
        XCTAssertEqual(HomeLayout.kidBTop(.leave(hasStatus: true)), 529)
        XCTAssertEqual(HomeLayout.kidBTop(.leave(hasStatus: false)), 475)
        XCTAssertEqual(HomeLayout.kidBTop(.timeLeft), 569)
        XCTAssertEqual(HomeLayout.kidBTop(.next), 442)
        for shape in [HomeLayout.KidAShape.leave(hasStatus: true), .leave(hasStatus: false), .timeLeft, .next] {
            let captionBottom = HomeLayout.kidBTop(shape) + 72 + 160 + 8 + 36
            XCTAssertLessThanOrEqual(captionBottom, 872, "\(shape)")
        }
    }

    func testThirteenInchIsTheBoard() {
        let layout = HomeLayout(sizing: Sizing(width: 1376, height: 1032))
        XCTAssertEqual(layout.clockCentre, CGPoint(x: 448, y: 528))
        XCTAssertEqual(layout.way, CGRect(x: 1232, y: 227, width: 80, height: 80))
        XCTAssertEqual(layout.nextRow.picture, CGRect(x: 928, y: 274, width: 104, height: 104))
        XCTAssertEqual(layout.nextRow.titleBaseline, 322)
        XCTAssertEqual(layout.nextRow.atBaseline, 360)
        XCTAssertEqual(layout.leaveNextRow.titleBaseline, 616)
        XCTAssertEqual(layout.leaveNextRow.atBaseline, 654)
        XCTAssertEqual(layout.button, CGRect(x: 928, y: 872, width: 384, height: 96))
    }
}
