import DesignSystem
import XCTest

/// The grown-up boards' shared lines hold on every iPad (layout v4, README "Grown-up").
final class GrownupLayoutTests: XCTestCase {
    private let iPads = [Sizing(width: 1376, height: 1032), Sizing(width: 1366, height: 1024),
                         Sizing(width: 1180, height: 820), Sizing(width: 1133, height: 744)]

    func testSharedLinesOnEveryIPad() {
        for sizing in iPads {
            let layout = GrownupLayout(sizing: sizing), w = sizing.width
            // x 64: ← = form card; x 1312: side column = action button = header right.
            XCTAssertEqual(layout.back.minX, layout.form.minX, accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.side.maxX, layout.right, accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.action.maxX, layout.right, accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.action.minX, layout.side.minX, accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.right, w - 64 * sizing.s, accuracy: 0.01, "\(w)")
            // Rows start 40 inside the card; the card and the side column never touch.
            XCTAssertEqual(layout.labelLeft, layout.form.minX + layout.formInset, accuracy: 0.01, "\(w)")
            XCTAssertGreaterThanOrEqual(layout.gap, 48 * sizing.s - 0.01, "\(w)")
            // The action button ends on 968; the header stays below the status band.
            XCTAssertEqual(layout.action.maxY, sizing.y(968), accuracy: 0.01, "\(w)")
            XCTAssertGreaterThanOrEqual(layout.back.minY, Sizing.statusBand, "\(w)")
        }
    }

    func testThirteenInchIsTheBoard() {
        let layout = GrownupLayout(sizing: Sizing(width: 1376, height: 1032))
        XCTAssertEqual(layout.back, CGRect(x: 64, y: 48, width: 80, height: 80))
        XCTAssertEqual(layout.form, CGRect(x: 64, y: 176, width: 818, height: 792))
        XCTAssertEqual(layout.side.minX, 930)
        XCTAssertEqual(layout.action, CGRect(x: 930, y: 872, width: 382, height: 96))
        XCTAssertEqual(layout.labelLeft, 104)
        XCTAssertEqual(layout.controlLeft, 232)
        XCTAssertEqual(layout.valueLeft, 280)
        XCTAssertEqual(layout.gap, 48)
    }
}
