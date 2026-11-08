import DesignSystem
import Missions
import XCTest

/// Spec "A2 redlines": the shared lines hold on every iPad, and nothing leaves its region.
final class MorningLayoutTests: XCTestCase {
    private let iPads = [Sizing(width: 1376, height: 1032), Sizing(width: 1366, height: 1024),
                         Sizing(width: 1180, height: 820), Sizing(width: 1133, height: 744)]

    func testSharedLinesOnEveryIPad() {
        for sizing in iPads {
            let layout = MorningLayout(sizing: sizing), w = sizing.width
            // x 64: back button = strip = kid list.
            XCTAssertEqual(layout.back.minX, layout.strip.minX, accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.back.minX, layout.kidRow(0).minX, accuracy: 0.01, "\(w)")
            // x 448: missions column = first circle = slide.
            XCTAssertEqual(layout.circleRect(0).minX, layout.columnLeft, accuracy: 0.01, "\(w)")
            XCTAssertEqual(layout.slide.minX, layout.columnLeft, accuracy: 0.01, "\(w)")
            // x 1312: header right = strip right = last circle = slide = pill.
            for edge in [layout.strip.maxX, layout.circleRect(5).maxX, layout.slide.maxX, layout.pill.maxX] {
                XCTAssertEqual(edge, layout.headerRight, accuracy: 0.01, "\(w)")
            }
            XCTAssertEqual(layout.headerRight, w - 64 * sizing.s, accuracy: 0.01, "\(w)")
            // Baselines: row 1 name = missions name line.
            XCTAssertEqual(layout.kidNameBaseline(0), layout.nameBaseline, accuracy: 0.01, "\(w)")
            // The kid band's notch stops short of the missions column.
            XCTAssertLessThan(layout.kidBand(0).maxX, layout.columnLeft, "\(w)")
            // Nothing below 968 or under the status bar band.
            XCTAssertLessThanOrEqual(layout.slide.maxY, sizing.y(968) + 0.01, "\(w)")
            XCTAssertGreaterThanOrEqual(layout.back.minY, Sizing.statusBand, "\(w)")
        }
    }

    func testThirteenInchIsTheBoard() {
        let layout = MorningLayout(sizing: Sizing(width: 1376, height: 1032))
        XCTAssertEqual(layout.columnLeft, 448)
        XCTAssertEqual(layout.pitch, 150.4, accuracy: 0.01)
        XCTAssertEqual(layout.circleRect(2).minX, 448 + 2 * 150.4, accuracy: 0.01)
        XCTAssertEqual(layout.kidFace(0), CGRect(x: 85, y: 553, width: 66, height: 66))
        XCTAssertEqual(layout.slide, CGRect(x: 448, y: 872, width: 864, height: 96))
        XCTAssertEqual(layout.pill, CGRect(x: 912, y: 872, width: 400, height: 96))
    }
}
