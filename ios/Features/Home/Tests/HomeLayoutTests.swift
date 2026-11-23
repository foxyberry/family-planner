import CoreGraphics
import DesignSystem
import Foundation
import Home
import XCTest

/// Spec A1 "Right panel numbers" (layout v75): the panel's parts on the 13" board and × s elsewhere.
final class HomeLayoutTests: XCTestCase {
    private let board = Sizing(width: 1376, height: 1032)

    /// Boards A1 / A1k / E1: one, two and three kid chips across 928–1336, gap 12, y 872–968.
    func testKidChipsShareThePanel() {
        let layout = HomeLayout(sizing: board)
        XCTAssertEqual(layout.chip(0, of: 1), CGRect(x: 928, y: 872, width: 408, height: 96))
        XCTAssertEqual(layout.chip(0, of: 2), CGRect(x: 928, y: 872, width: 198, height: 96))
        XCTAssertEqual(layout.chip(1, of: 2), CGRect(x: 1138, y: 872, width: 198, height: 96))
        XCTAssertEqual(layout.chip(2, of: 3).minX, 1208, accuracy: 0.5)
        XCTAssertEqual(layout.chip(2, of: 3).width, 128, accuracy: 0.5)
    }

    /// Board A1k: the card 736–848; a mission row 631–712 right above it; plain rows climb 16 apart
    /// (their faces end at 615 and 530 on the board).
    func testRowsClimbFromAboveTheCard() {
        let layout = HomeLayout(sizing: board)
        XCTAssertEqual(layout.card, CGRect(x: 928, y: 736, width: 408, height: 112))
        let kinds = [true, false, false]
        XCTAssertEqual(layout.row(0, of: kinds), CGRect(x: 928, y: 631, width: 408, height: 81))
        XCTAssertEqual(layout.row(1, of: kinds).maxY, 615)
        XCTAssertEqual(layout.row(2, of: kinds).maxY, 530)
    }

    /// Spec A1 "Items": as many rows as fit under the top buttons; the farthest drop off the top.
    func testOnlyTheRowsThatFitShow() {
        XCTAssertEqual(HomeLayout.rowsThatFit([]), 0)
        XCTAssertEqual(HomeLayout.rowsThatFit(Array(repeating: false, count: 3)), 3)
        let fit = HomeLayout.rowsThatFit(Array(repeating: false, count: 20))
        XCTAssertEqual(fit, 6, "712 − 6 × 85 + 16 ≥ 148")
        XCTAssertLessThan(HomeLayout.rowsThatFit(Array(repeating: true, count: 20)), fit, "mission rows are taller")
    }

    /// Spec "Sizing: one scale, no floors": every part is the board × s on a smaller iPad.
    func testEveryPartIsTheBoardTimesS() {
        let mini = Sizing(width: 1133, height: 744)
        let layout = HomeLayout(sizing: mini), s = mini.s
        XCTAssertEqual(layout.card.height, 112 * s, accuracy: 0.5)
        XCTAssertEqual(layout.chip(0, of: 2).width, 198 * s, accuracy: 0.5)
        XCTAssertEqual(layout.row(0, of: [false]).height, 69 * s, accuracy: 0.5)
    }
}
