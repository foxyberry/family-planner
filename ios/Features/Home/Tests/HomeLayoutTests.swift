import DesignSystem
import Home
import XCTest

/// Boards A1, A1m, A1b, A1n, E3, E3b, E3h and E1 (layout v71): the panel's lines hold on every iPad, and
/// nothing leaves the panel.
final class HomeLayoutTests: XCTestCase {
    private let iPads = [Sizing(width: 1376, height: 1032), Sizing(width: 1366, height: 1024),
                         Sizing(width: 1180, height: 820), Sizing(width: 1133, height: 744), Sizing(width: 890, height: 626)]

    func testPanelLinesOnEveryIPad() {
        for sizing in iPads {
            for note in [false, true] {
                assertPanelLines(HomeLayout(sizing: sizing, dayNote: note), sizing)
            }
        }
    }

    private func assertPanelLines(_ layout: HomeLayout, _ sizing: Sizing) {
        do {
            let w = sizing.width
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

    /// "kidBRule": Kid B's name 40 below Kid A's last part, never lower than 620; the Now row's
    /// picture 50 below the name baseline, the Next row 126 below it (layout v71, ±1 on the boards).
    /// Expected values (name baseline, Now picture top, Next picture top) are the boards' A1, A1m and
    /// A1b, A1n, E3 and E3b.
    func testKidBFollowsKidA() {
        let layout = HomeLayout(sizing: Sizing(width: 1376, height: 1032))
        let boards: [(HomeLayout.KidAEnd, CGFloat, CGFloat, CGFloat)] = [
            (.status, 500, 550, 676), (.timeLeft, 464, 515, 640), (.timeLeftRow, 550, 601, 726),
            (.nextRow, 452, 502, 628),
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
            // Spec: the block ends by 837 on every board, above the main button (872).
            XCTAssertLessThanOrEqual(next.atBaseline + 11, 837, "\(end)")
        }
        // Board A1: Now "Now" 572, "Breakfast" 612, the time line 651; Next 697 / 738 / 776.
        let a1 = layout.kidBTop(after: .status)
        XCTAssertEqual(layout.kidBNowRow(kidBTop: a1).labelBaseline ?? 0, 572, accuracy: 1)
        XCTAssertEqual(layout.kidBNowRow(kidBTop: a1).titleBaseline, 612, accuracy: 1)
        XCTAssertEqual(layout.kidBNowRow(kidBTop: a1).atBaseline, 651, accuracy: 1)
        XCTAssertEqual(layout.kidBNextRow(kidBTop: a1).labelBaseline ?? 0, 697, accuracy: 1)
        XCTAssertEqual(layout.kidBNextRow(kidBTop: a1).titleBaseline, 738, accuracy: 1)
        XCTAssertEqual(layout.kidBNextRow(kidBTop: a1).atBaseline, 776, accuracy: 1)
        XCTAssertEqual(layout.kidALabelBaseline, 301)
        XCTAssertEqual(layout.kidATimeBaseline, 373)
        XCTAssertEqual(layout.kidAStatusBaseline, 410)
        XCTAssertEqual(layout.timeLeftRow.picture, CGRect(x: 928, y: 403, width: 80, height: 80))
        XCTAssertEqual(layout.timeLeftRow.textLeft, 1024)
        XCTAssertEqual(layout.timeLeftRow.titleBaseline, 440)
        XCTAssertEqual(layout.timeLeftRow.atBaseline, 471)
    }

    /// Board E3h (layout v71): the holiday's name 32 below the weekday (168 / 200) pushes Kid A's
    /// block down by 32; Kid B follows it (name 483, Now 534, Next 659, ±1 on the board).
    func testTheHolidayNameLinePushesThePanelDown() {
        let plain = HomeLayout(sizing: .thirteenInch), holiday = HomeLayout(sizing: .thirteenInch, dayNote: true)
        XCTAssertEqual(holiday.weekdayBaseline, 168)
        XCTAssertEqual(holiday.dayNoteBaseline, 200)
        XCTAssertEqual(holiday.kidBadge(top: holiday.kidATop).minY, 231, accuracy: 1, "board: ring 230")
        XCTAssertEqual(holiday.kidNameBaseline(top: holiday.kidATop), 254, accuracy: 1)
        XCTAssertEqual(holiday.nextRow.picture, CGRect(x: 928, y: 306, width: 104, height: 104), "board: 305 ±1")
        XCTAssertEqual(holiday.nextRow.labelBaseline ?? 0, 326, accuracy: 1)
        XCTAssertEqual(holiday.nextRow.titleBaseline, 367, accuracy: 1)
        XCTAssertEqual(holiday.nextRow.atBaseline, 405, accuracy: 1)
        let top = holiday.kidBTop(after: .nextRow)
        XCTAssertEqual(holiday.kidNameBaseline(top: top), 483, accuracy: 1)
        XCTAssertEqual(holiday.kidBNowRow(kidBTop: top).picture.minY, 534, accuracy: 1)
        XCTAssertEqual(holiday.kidBNextRow(kidBTop: top).picture.minY, 659, accuracy: 1)
        // Every Kid A part moves by exactly the name line; the buttons and the main button stay.
        XCTAssertEqual(holiday.kidAPicture.minY - plain.kidAPicture.minY, 32)
        XCTAssertEqual(holiday.timeLeftRow.picture.minY - plain.timeLeftRow.picture.minY, 32)
        XCTAssertEqual(holiday.leaveNextRow.picture.minY - plain.leaveNextRow.picture.minY, 32)
        XCTAssertEqual(holiday.button, plain.button)
        XCTAssertEqual(holiday.calendarButton, plain.calendarButton)
    }

    /// No board draws the name line over the longer blocks (A1, A1n). Kid B keeps its 40 gap, and
    /// every block ends above the main button's top (872). The A1n evening with a name line (a public
    /// holiday's bed time with a Tomorrow row) ends at 869, past the spec's 837.
    func testEveryBlockEndsAboveTheMainButtonWithTheNameLine() {
        let holiday = HomeLayout(sizing: .thirteenInch, dayNote: true)
        for end in HomeLayout.KidAEnd.allCases {
            let top = holiday.kidBTop(after: end)
            let next = holiday.kidBNextRow(kidBTop: top)
            XCTAssertLessThan(next.atBaseline + 11, holiday.button.minY, "\(end)")
        }
        let evening = holiday.kidBNextRow(kidBTop: holiday.kidBTop(after: .timeLeftRow))
        XCTAssertEqual(evening.atBaseline + 11, 869, accuracy: 1)
    }

    func testThirteenInchIsTheBoard() {
        let layout = HomeLayout(sizing: Sizing(width: 1376, height: 1032))
        XCTAssertEqual(layout.clockCentre, CGPoint(x: 448, y: 528))
        // Layout v71: the panel starts 36 lower (weekday 168, Kid A's ring 199, name 223).
        XCTAssertEqual(layout.weekdayBaseline, 168)
        XCTAssertEqual(layout.kidBadge(top: layout.kidATop), CGRect(x: 928, y: 199, width: 48, height: 48))
        XCTAssertEqual(layout.kidNameBaseline(top: layout.kidATop), 223)
        XCTAssertEqual(layout.kidAPicture, CGRect(x: 928, y: 277, width: 96, height: 96))
        XCTAssertEqual(layout.nextRow.picture, CGRect(x: 928, y: 274, width: 104, height: 104))
        XCTAssertEqual(layout.nextRow.labelBaseline, 295)
        XCTAssertEqual(layout.nextRow.titleBaseline, 336)
        XCTAssertEqual(layout.nextRow.atBaseline, 374)
        XCTAssertEqual(layout.leaveNextRow.picture.minY, 471)
        XCTAssertEqual(layout.leaveNextRow.labelBaseline ?? 0, 493, accuracy: 1)
        XCTAssertEqual(layout.leaveNextRow.titleBaseline, 533)
        XCTAssertEqual(layout.leaveNextRow.atBaseline, 572, accuracy: 1)
        XCTAssertEqual(layout.button, CGRect(x: 928, y: 872, width: 408, height: 96), "layout v29")
        XCTAssertEqual(layout.pencil, CGRect(x: 1240, y: 36, width: 96, height: 96), "as tall as the sky switch")
        XCTAssertEqual(layout.calendarButton, CGRect(x: 1128, y: 36, width: 96, height: 96), "16 left of the pencil")
        // The weekday line (head 36) passes under both buttons (bottom 132).
        XCTAssertGreaterThan(layout.weekdayBaseline - 36, layout.calendarButton.maxY - 1)
    }

    /// Spec "Sizing: one scale, no floors": on every window each part is its 13" rect × s.
    func testEveryPartIsTheBoardTimesS() {
        let l = HomeLayout(sizing: .thirteenInch)
        let rects = { (l: HomeLayout) in
            [l.skySwitch, l.pencil, l.calendarButton, l.kidAPicture, l.nextRow.picture, l.timeLeftRow.picture, l.button,
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
