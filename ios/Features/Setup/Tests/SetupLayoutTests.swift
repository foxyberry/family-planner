import DesignSystem
import Setup
import XCTest

/// Boards S1–S4 hold the grown-up lines on every iPad (S1's card lines: `FormLinesTests`).
final class SetupLayoutTests: XCTestCase {
    private let iPads = [Sizing(width: 1376, height: 1032), Sizing(width: 1366, height: 1024, safeTop: 32),
                         Sizing(width: 1180, height: 820), Sizing(width: 1133, height: 744)]

    func testSharedLinesOnEveryIPad() {
        for sizing in iPads {
            let layout = SetupLayout(sizing: sizing), w = sizing.width
            // The step dots end the header on 1336, with the side column and the action button.
            XCTAssertEqual(layout.grown.action.maxX, layout.grown.right, accuracy: 0.01, "\(w)")
            // The cards never reach the side column.
            XCTAssertLessThanOrEqual(layout.grown.form.maxX, layout.grown.side.minX, "\(w)")
        }
    }

    func testThirteenInchIsTheBoard() {
        let layout = SetupLayout(sizing: Sizing(width: 1376, height: 1032))
        XCTAssertEqual(layout.s4Side(936, 275), CGPoint(x: 72, y: 127))
        XCTAssertEqual(layout.schoolFieldWidth, 610)
    }
}
