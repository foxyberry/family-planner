import DesignSystem
import Setup
import XCTest

/// Boards S1–S4 (layout v10) hold the grown-up lines on every iPad.
final class SetupLayoutTests: XCTestCase {
    private let iPads = [Sizing(width: 1376, height: 1032), Sizing(width: 1366, height: 1024, safeTop: 32),
                         Sizing(width: 1180, height: 820), Sizing(width: 1133, height: 744)]

    func testSharedLinesOnEveryIPad() {
        for sizing in iPads {
            let layout = SetupLayout(sizing: sizing), w = sizing.width
            // The step dots end the header on 1336, with the side column and the action button.
            XCTAssertEqual(layout.grown.action.maxX, layout.grown.right, accuracy: 0.01, "\(w)")
            // S1 cards are the form card's width on 40; each next card starts 32 below the last.
            XCTAssertEqual(layout.kidCard(0).minX, layout.grown.form.minX, accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.kidCard(0).minY, layout.grown.contentTop, accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.kidCard(0).width, layout.grown.form.width, accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.kidCard(1).minY, layout.kidCard(0).maxY + layout.cardGap, accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.kidCard(0).height, layout.cardHeight, accuracy: 0.01, "\(w)")
            // S4 rows start on the label line and keep their pitch.
            XCTAssertEqual(layout.grown.form.minX + layout.s4Main(80, 216).x, layout.grown.labelLeft,
                           accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.s4Main(80, 356).y - layout.s4Main(80, 216).y, layout.length(140),
                           accuracy: 0.01, "\(w)")
            // The cards never reach the side column.
            XCTAssertLessThanOrEqual(layout.grown.form.maxX, layout.grown.side.minX, "\(w)")
        }
    }

    func testThirteenInchIsTheBoard() {
        let layout = SetupLayout(sizing: Sizing(width: 1376, height: 1032))
        XCTAssertEqual(layout.kidCard(0), CGRect(x: 40, y: 176, width: 800, height: 304))
        XCTAssertEqual(layout.kidCard(1).minY, 500, "layout v18: cards 304 tall, 20 apart")
        XCTAssertEqual(layout.s4Main(80, 216), CGPoint(x: 40, y: 40), "board S4: the first row at (80, 216)")
        XCTAssertEqual(layout.s4Side(936, 303), CGPoint(x: 72, y: 127))
        XCTAssertEqual(layout.schoolFieldWidth, 610)
    }
}
