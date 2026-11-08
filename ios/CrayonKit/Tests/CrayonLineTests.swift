import CoreGraphics
import CrayonKit
import XCTest

/// Open marker lines (the way strip's road) and the hill shape.
final class CrayonLineTests: XCTestCase {
    private let road = stride(from: CGFloat(40), through: 1208, by: 16).map { CGPoint(x: $0, y: 250) }

    func testMarkerLineStaysOpenAndNearItsPoints() {
        let line = CrayonGeometry.markerLine(road, marker: .standard, seed: 7)
        XCTAssertGreaterThan(line.count, 90)
        let first = try! XCTUnwrap(line.first), last = try! XCTUnwrap(line.last)
        // Open: it starts at the left end and stops at the right end, no run back to the start.
        XCTAssertEqual(first.x, 40, accuracy: 4)
        XCTAssertEqual(last.x, 1208, accuracy: 4)
        XCTAssertTrue(line.allSatisfy { abs($0.y - 250) < 4 })
    }

    func testMarkerLineIsTheSameForTheSameSeed() {
        XCTAssertEqual(CrayonGeometry.markerLine(road, marker: .standard, seed: 7),
                       CrayonGeometry.markerLine(road, marker: .standard, seed: 7))
        XCTAssertNotEqual(CrayonGeometry.markerLine(road, marker: .standard, seed: 7),
                          CrayonGeometry.markerLine(road, marker: .standard, seed: 8))
    }

    func testHillPeaksAtTheTopCentre() {
        let path = CrayonGeometry.idealPath(kind: .hill, in: CGRect(x: 0, y: 0, width: 300, height: 80))
        XCTAssertTrue(path.contains(CGPoint(x: 150, y: 4)))
        XCTAssertFalse(path.contains(CGPoint(x: 20, y: 10)))
        XCTAssertEqual(path.boundingBoxOfPath.minY, 0, accuracy: 0.5)
    }
}
