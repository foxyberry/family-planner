import DesignSystem
import XCTest

/// The grown-up boards' shared lines hold on every iPad (layout v4, README "Grown-up").
final class GrownupLayoutTests: XCTestCase {
    private let iPads = [Sizing(width: 1376, height: 1032), Sizing(width: 1366, height: 1024),
                         Sizing(width: 1180, height: 820), Sizing(width: 1133, height: 744)]

    func testSharedLinesOnEveryIPad() {
        for sizing in iPads {
            let layout = GrownupLayout(sizing: sizing), w = sizing.width
            // x 40: ← = form card; x 1336: side column = action button = header right (v31).
            XCTAssertEqual(layout.back.minX, layout.form.minX, accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.side.maxX, layout.right, accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.action.maxX, layout.right, accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.action.minX, layout.side.minX, accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.right, w - 40 * sizing.s, accuracy: 0.01, "\(w)")
            // Rows start 40 inside the card; the card and the side column never touch.
            XCTAssertEqual(layout.labelLeft, layout.form.minX + layout.formInset, accuracy: 0.01, "\(w)")
            XCTAssertGreaterThanOrEqual(layout.gap, 24 * sizing.s - 0.01, "\(w)")
            // The action button ends on 968; the header stays below the status band.
            XCTAssertEqual(layout.action.maxY, sizing.y(968), accuracy: 0.01, "\(w)")
            XCTAssertGreaterThanOrEqual(layout.back.minY, Sizing.statusBand, "\(w)")
        }
    }

    func testThirteenInchIsTheBoard() {
        let layout = GrownupLayout(sizing: Sizing(width: 1376, height: 1032))
        XCTAssertEqual(layout.back, CGRect(x: 40, y: 48, width: 80, height: 80))
        XCTAssertEqual(layout.form, CGRect(x: 40, y: 176, width: 800, height: 792))
        XCTAssertEqual(layout.side.minX, 864)
        XCTAssertEqual(layout.side.width, 472)
        XCTAssertEqual(layout.action, CGRect(x: 864, y: 872, width: 472, height: 96))
        XCTAssertEqual(layout.labelLeft, 80)
        XCTAssertEqual(layout.controlLeft, 208)
        XCTAssertEqual(layout.valueLeft, 256)
        XCTAssertEqual(layout.gap, 24)
    }
}
