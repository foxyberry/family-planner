import CoreGraphics
import CrayonKit
import XCTest

/// Pie sectors for the 24-hour clock: angles clockwise from 12 o'clock, centred in the rect.
final class CrayonSectorTests: XCTestCase {
    private let rect = CGRect(x: 0, y: 0, width: 200, height: 200)

    func testQuarterSectorCoversTopRight() {
        let path = CrayonGeometry.idealPath(kind: .sector(startDegrees: 0, endDegrees: 90), in: rect)
        XCTAssertTrue(path.contains(CGPoint(x: 150, y: 50)))
        XCTAssertFalse(path.contains(CGPoint(x: 50, y: 50)))
        XCTAssertFalse(path.contains(CGPoint(x: 150, y: 150)))
    }

    func testSectorAcrossMidnightWraps() {
        // 300° to 420° (= 60°) covers the top.
        let path = CrayonGeometry.idealPath(kind: .sector(startDegrees: 300, endDegrees: 420), in: rect)
        XCTAssertTrue(path.contains(CGPoint(x: 100, y: 20)))
        XCTAssertFalse(path.contains(CGPoint(x: 100, y: 180)))
    }

    func testSectorOutlineStaysOnTheDisc() {
        let points = CrayonGeometry.idealOutline(kind: .sector(startDegrees: 30, endDegrees: 200), in: rect, spacing: 4)
        for p in points { XCTAssertLessThanOrEqual(hypot(p.x - 100, p.y - 100), 100.5) }
    }
}
