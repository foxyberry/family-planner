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
                         layout.nowNext(kidBTop: layout.kidBTop).x, layout.button.minX]
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

    /// Layout v5 "Home panel lines": Kid B's name on 584, the circles' bottom on 792 and the captions
    /// above the button (872) whatever Kid A shows; Kid A's rows end above Kid B.
    func testFixedPanelLines() {
        let layout = HomeLayout(sizing: Sizing(width: 1376, height: 1032))
        XCTAssertEqual(layout.kidNameBaseline(top: layout.kidBTop), 584)
        XCTAssertEqual(layout.nowNext(kidBTop: layout.kidBTop).y + 160, 792)
        XCTAssertLessThanOrEqual(792 + 8 + 36, 872)
        XCTAssertEqual(layout.firstLineBaseline, 301)
        XCTAssertEqual(layout.timeBaseline, 402)
        for row in [layout.nextRow, layout.timeLeftRow] {
            XCTAssertLessThan(row.picture.maxY, layout.kidBTop)
        }
        XCTAssertEqual(layout.leaveNextCaptionBaseline, 584)
    }

    func testThirteenInchIsTheBoard() {
        let layout = HomeLayout(sizing: Sizing(width: 1376, height: 1032))
        XCTAssertEqual(layout.clockCentre, CGPoint(x: 448, y: 528))
        XCTAssertEqual(layout.way, CGRect(x: 1232, y: 227, width: 80, height: 80))
        XCTAssertEqual(layout.nextRow.picture, CGRect(x: 928, y: 315, width: 104, height: 104))
        XCTAssertEqual(layout.nextRow.titleBaseline, 363)
        XCTAssertEqual(layout.nextRow.atBaseline, 401)
        XCTAssertEqual(layout.timeLeftRow.picture.minY, 436)
        XCTAssertEqual(layout.leaveNextRow.titleBaseline, 646)
        XCTAssertEqual(layout.leaveNextRow.atBaseline, 684)
        XCTAssertEqual(layout.button, CGRect(x: 928, y: 872, width: 384, height: 96))
    }
}
