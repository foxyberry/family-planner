import DesignSystem
import Home
import XCTest

/// Boards A1, A1m, A1b, A1n, E1, E3, E3b (layout v68): the panel's lines hold on every iPad, and
/// nothing leaves the panel.
final class HomeLayoutTests: XCTestCase {
    private let iPads = [Sizing(width: 1376, height: 1032), Sizing(width: 1366, height: 1024),
                         Sizing(width: 1180, height: 820), Sizing(width: 1133, height: 744), Sizing(width: 890, height: 626)]

    func testPanelLinesOnEveryIPad() {
        for sizing in iPads {
            let layout = HomeLayout(sizing: sizing), w = sizing.width
            // x 928: badges, rows, Kid B's Now and Next rows and the button start on the panel's left line.
            let kidBTop = layout.kidBTop(after: .status)
            let lefts = [layout.kidBadge(top: layout.kidATop).minX, layout.nextRow.picture.minX,
                         layout.timeLeftRow.picture.minX, layout.leaveNextRow.picture.minX,
                         layout.kidBNowRow(kidBTop: kidBTop).picture.minX,
                         layout.kidBNextRow(kidBTop: kidBTop).picture.minX, layout.button.minX]
            for left in lefts {
                XCTAssertEqual(left, layout.panelLeft, accuracy: 0.01, "\(w)")
            }
            // Look ①: the Kid A picture starts on 928 too; the button ends on the panel's right line.
            XCTAssertEqual(layout.kidAPicture.minX, layout.panelLeft, accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.button.maxX, layout.panelRight, accuracy: 0.01, "\(w)")
            // Layout v29: the right margin is 40, the sky switch's on the left.
            XCTAssertEqual(layout.panelRight, w - 40 * sizing.s, accuracy: 0.01, "\(w)")
            // Each row's text starts 16 right of its picture (look ①).
            for row in [layout.nextRow, layout.leaveNextRow, layout.kidBNowRow(kidBTop: kidBTop),
                        layout.kidBNextRow(kidBTop: kidBTop)] {
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

    /// "kidBRule": Kid B's name 40 below Kid A's last part, never lower than 584; the Now row's
    /// picture 50 below the name baseline, the Next row 126 below it (layout v68, ±1 on the boards).
    /// Expected values (name baseline, Now picture top, Next picture top) are the boards' A1, A1m and
    /// A1b, A1n, E3 and E3b.
    func testKidBFollowsKidA() {
        let layout = HomeLayout(sizing: Sizing(width: 1376, height: 1032))
        let boards: [(HomeLayout.KidAEnd, CGFloat, CGFloat, CGFloat)] = [
            (.status, 464, 514, 640), (.timeLeft, 428, 479, 604), (.timeLeftRow, 514, 565, 690),
            (.nextRow, 416, 466, 592),
        ]
        for (end, name, nowTop, nextTop) in boards {
            let top = layout.kidBTop(after: end)
            let now = layout.kidBNowRow(kidBTop: top), next = layout.kidBNextRow(kidBTop: top)
            XCTAssertEqual(layout.kidNameBaseline(top: top), name, accuracy: 1, "\(end)")
            XCTAssertEqual(now.picture.minY, nowTop, accuracy: 1, "\(end)")
            XCTAssertEqual(next.picture.minY, nextTop, accuracy: 1, "\(end)")
            XCTAssertEqual(now.picture.size, CGSize(width: 104, height: 104), "\(end)")
            XCTAssertEqual(next.picture.minY - now.picture.minY, 126, "\(end)")
            // Caption / title / time line on the picture top + 21 / 62 / 100 (boards ±1).
            XCTAssertEqual(next.labelBaseline ?? 0, nextTop + 21, accuracy: 1, "\(end)")
            XCTAssertEqual(next.titleBaseline, nextTop + 62, accuracy: 1, "\(end)")
            XCTAssertEqual(next.atBaseline, nextTop + 100, accuracy: 1, "\(end)")
            // Spec: the block ends by 801 on every board, above the main button (872).
            XCTAssertLessThanOrEqual(next.atBaseline + 11, 801, "\(end)")
        }
        // Board A1: Now "Now" 536, "Breakfast" 576, the time line 615; Next 661 / 702 / 740.
        let a1 = layout.kidBTop(after: .status)
        XCTAssertEqual(layout.kidBNowRow(kidBTop: a1).labelBaseline ?? 0, 536, accuracy: 1)
        XCTAssertEqual(layout.kidBNowRow(kidBTop: a1).titleBaseline, 576, accuracy: 1)
        XCTAssertEqual(layout.kidBNowRow(kidBTop: a1).atBaseline, 615, accuracy: 1)
        XCTAssertEqual(layout.kidBNextRow(kidBTop: a1).labelBaseline ?? 0, 661, accuracy: 1)
        XCTAssertEqual(layout.kidBNextRow(kidBTop: a1).titleBaseline, 702, accuracy: 1)
        XCTAssertEqual(layout.kidBNextRow(kidBTop: a1).atBaseline, 740, accuracy: 1)
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
        XCTAssertEqual(layout.leaveNextRow.labelBaseline ?? 0, 456, accuracy: 1)
        XCTAssertEqual(layout.leaveNextRow.titleBaseline, 497)
        XCTAssertEqual(layout.leaveNextRow.atBaseline, 535, accuracy: 1)
        XCTAssertEqual(layout.button, CGRect(x: 928, y: 872, width: 408, height: 96), "layout v29")
        XCTAssertEqual(layout.pencil, CGRect(x: 1240, y: 36, width: 96, height: 96), "as tall as the sky switch")
    }

    /// Spec "Sizing: one scale, no floors": on every window each part is its 13" rect × s.
    func testEveryPartIsTheBoardTimesS() {
        let l = HomeLayout(sizing: .thirteenInch)
        let rects = { (l: HomeLayout) in
            [l.skySwitch, l.pencil, l.kidAPicture, l.nextRow.picture, l.timeLeftRow.picture, l.button,
             l.kidBadge(top: l.kidATop), l.kidBNowRow(kidBTop: l.kidBTop(after: .status)).picture,
             l.kidBNextRow(kidBTop: l.kidBTop(after: .timeLeftRow)).picture]
        }
        let board = rects(l)
        for sizing in iPads {
            assertScaled(rects(HomeLayout(sizing: sizing)), board, sizing)
        }
    }

    /// A 13" rect on `sizing`: x and sizes × s, y from the safe top.
    private func scaled(_ rect: CGRect, _ sizing: Sizing) -> CGRect {
        CGRect(x: rect.minX * sizing.s, y: sizing.y(rect.minY), width: rect.width * sizing.s,
               height: rect.height * sizing.s)
    }

    private func assertScaled(_ rects: [CGRect], _ board: [CGRect], _ sizing: Sizing) {
        for (a, b) in zip(rects, board).map({ ($0, scaled($1, sizing)) }) {
            XCTAssertEqual(a.minX, b.minX, accuracy: 0.01, "\(sizing.window)")
            XCTAssertEqual(a.minY, b.minY, accuracy: 0.01, "\(sizing.window)")
            XCTAssertEqual(a.width, b.width, accuracy: 0.01, "\(sizing.window)")
            XCTAssertEqual(a.height, b.height, accuracy: 0.01, "\(sizing.window)")
        }
    }
}
