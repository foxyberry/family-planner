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
                         layout.nowNext(kidBTop: layout.kidBTop(after: .status)).x, layout.button.minX]
            for left in lefts {
                XCTAssertEqual(left, layout.panelLeft, accuracy: 0.01, "\(w)")
            }
            // Look ①: the Kid A picture starts on 928 too; the button ends on the panel's right line.
            XCTAssertEqual(layout.kidAPicture.minX, layout.panelLeft, accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.button.maxX, layout.panelRight, accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.panelRight, w - 64 * sizing.s, accuracy: 0.01, "\(w)")
            // Each row's text starts 16 right of its picture (look ①).
            for row in [layout.nextRow, layout.leaveNextRow] {
                XCTAssertEqual(row.textLeft, row.picture.maxX + 16 * sizing.s, accuracy: 0.01, "\(w)")
            }
            XCTAssertEqual(layout.kidATextLeft, layout.kidAPicture.maxX + 16 * sizing.s, accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.timeLeftRow.textLeft, layout.timeLeftRow.picture.maxX + 16 * sizing.s,
                           accuracy: 0.01, "\(w)")
            // The button ends on 968; the sky switch stays below the status band.
            XCTAssertEqual(layout.button.maxY, sizing.y(968), accuracy: 0.01, "\(w)")
            XCTAssertGreaterThanOrEqual(layout.skySwitch.minY, Sizing.statusBand, "\(w)")
        }
    }

    /// "kidBRule": Kid B's name 40 below Kid A's last part, never lower than 584; the circles 48 below
    /// the name baseline. Expected values are the v17 boards' (A1, A1m, A1n, E3), ±1.
    func testKidBFollowsKidA() {
        let layout = HomeLayout(sizing: Sizing(width: 1376, height: 1032))
        let boards: [(HomeLayout.KidAEnd, CGFloat, CGFloat)] = [
            (.status, 464, 672), (.timeLeft, 428, 636), (.timeLeftRow, 514, 722), (.nextRow, 416, 624),
        ]
        for (end, name, circlesBottom) in boards {
            let top = layout.kidBTop(after: end)
            XCTAssertEqual(layout.kidNameBaseline(top: top), name, accuracy: 1, "\(end)")
            XCTAssertEqual(layout.nowNext(kidBTop: top).y + 160, circlesBottom, accuracy: 1, "\(end)")
            XCTAssertLessThanOrEqual(circlesBottom + 33 + 12, 872, "captions stay above the button")
        }
        XCTAssertEqual(layout.kidALabelBaseline, 265)
        XCTAssertEqual(layout.kidATimeBaseline, 337)
        XCTAssertEqual(layout.kidAStatusBaseline, 374)
        XCTAssertEqual(layout.timeLeftRow.picture, CGRect(x: 928, y: 367, width: 80, height: 80))
        XCTAssertEqual(layout.timeLeftRow.textLeft, 1024)
        XCTAssertEqual(layout.timeLeftRow.titleBaseline, 404)
    }

    func testThirteenInchIsTheBoard() {
        let layout = HomeLayout(sizing: Sizing(width: 1376, height: 1032))
        XCTAssertEqual(layout.clockCentre, CGPoint(x: 448, y: 528))
        XCTAssertEqual(layout.kidAPicture, CGRect(x: 928, y: 241, width: 96, height: 96))
        XCTAssertEqual(layout.nextRow.picture, CGRect(x: 928, y: 238, width: 104, height: 104))
        XCTAssertEqual(layout.nextRow.labelBaseline, 259)
        XCTAssertEqual(layout.nextRow.titleBaseline, 300)
        XCTAssertEqual(layout.nextRow.atBaseline, 338)
        XCTAssertEqual(layout.leaveNextRow.labelBaseline, 456, accuracy: 1)
        XCTAssertEqual(layout.leaveNextRow.titleBaseline, 497)
        XCTAssertEqual(layout.leaveNextRow.atBaseline, 535, accuracy: 1)
        XCTAssertEqual(layout.button, CGRect(x: 928, y: 872, width: 384, height: 96))
    }
}
