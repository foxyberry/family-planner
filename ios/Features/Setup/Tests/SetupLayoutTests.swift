import DesignSystem
import Setup
import XCTest

/// Boards S1–S4 hold the grown-up lines on every iPad (S1's card lines: `FormLinesTests`).
final class SetupLayoutTests: XCTestCase {
    private let iPads = [Sizing(width: 1376, height: 1032), Sizing(width: 1366, height: 1024, safeTop: 32),
                         Sizing(width: 1180, height: 820), Sizing(width: 1133, height: 744), Sizing(width: 890, height: 626)]

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

    /// Spec "Sizing: one scale, no floors": on every window each part is its 13" rect × s.
    func testEveryPartIsTheBoardTimesS() {
        let l = SetupLayout(sizing: .thirteenInch)
        let board = [l.grown.back, l.grown.form, l.grown.side, l.grown.action]
        for sizing in iPads {
            let l = SetupLayout(sizing: sizing)
            assertScaled([l.grown.back, l.grown.form, l.grown.side, l.grown.action], board, sizing)
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
