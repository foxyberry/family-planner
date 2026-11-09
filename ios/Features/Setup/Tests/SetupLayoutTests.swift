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
            // The step dots end on 1312 with the side column and the action button.
            XCTAssertEqual(layout.dots.maxX, layout.grown.right, accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.grown.action.maxX, layout.grown.right, accuracy: 0.01, "\(w)")
            // S1 cards are the form card's width on 64; each next card starts 32 below the last.
            XCTAssertEqual(layout.kidCard(0).minX, layout.grown.form.minX, accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.kidCard(0).minY, layout.grown.contentTop, accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.kidCard(0).width, layout.grown.form.width, accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.kidCard(1).minY, layout.kidCard(0).maxY + layout.cardGap, accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.kidCard(0).height, layout.cardHeight, accuracy: 0.01, "\(w)")
            // S4 rows start on the label line and keep their pitch.
            XCTAssertEqual(layout.settingRow(0).minX, layout.grown.labelLeft, accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.settingRow(1).minY - layout.settingRow(0).maxY, layout.settingRowGap,
                           accuracy: 0.01, "\(w)")
            // Everything stays below the status band and inside the window.
            XCTAssertGreaterThanOrEqual(layout.dots.minY, sizing.safeTop, "\(w)")
            XCTAssertLessThanOrEqual(layout.grown.form.maxX, layout.grown.side.minX, "\(w)")
        }
    }

    func testThirteenInchIsTheBoard() {
        let layout = SetupLayout(sizing: Sizing(width: 1376, height: 1032))
        XCTAssertEqual(layout.dots, CGRect(x: 1176, y: 74, width: 136, height: 28))
        XCTAssertEqual(layout.kidCard(0), CGRect(x: 64, y: 176, width: 818, height: 296))
        XCTAssertEqual(layout.kidCard(1).minY, 504, "board S1: the second card's Name row is at 548")
        XCTAssertEqual(layout.settingRow(0).minY, 216)
        XCTAssertEqual(layout.settingRow(1).minY, 356)
        XCTAssertEqual(layout.schoolFieldWidth, 610)
    }
}
