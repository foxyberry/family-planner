import CoreGraphics
@testable import CrayonKit
import XCTest

/// Wrist-flick colouring (design ST-13): short, slightly bent strokes that taper at both ends and
/// overlap along each row, like a child colouring with the wrist fixed.
final class CrayonFlickTests: XCTestCase {
    private let rect = CGRect(x: 0, y: 0, width: 400, height: 120)
    private let kind = CrayonShapeKind.roundedRect(cornerRadius: 24)

    private func style(edgeJitter: CGFloat = 0.5) -> HachureStyle {
        HachureStyle(degrees: -30, edgeJitter: edgeJitter)
    }

    private func geometry(seed: UInt32 = 7, marker: MarkerStyle = .standard,
                          style: HachureStyle? = nil) -> CrayonGeometry {
        CrayonGeometry(kind: kind, in: rect, seed: seed, marker: marker, hachure: style ?? self.style())
    }

    func testDesignDefaults() {
        let s = HachureStyle(degrees: 0)
        XCTAssertEqual(s.gap, 4.1)
        XCTAssertEqual(s.weight, 4.6)
        XCTAssertEqual(s.strokeLength, 30...56)
        XCTAssertEqual(s.bendRadius, 120)
        XCTAssertEqual(s.taper, 0.3)
        XCTAssertEqual(s.edgeJitter, 0.5)
        XCTAssertEqual(s.angleJitter, 4)
    }

    func testRowsAreOneGapApart() {
        let polygon = CrayonGeometry.idealOutline(kind: kind, in: rect, spacing: 2)
        let rows = Flicks.rows(polygon: polygon, degrees: 0, gap: 4.1)
        let ys = Set(rows.map { ($0.a.y * 1000).rounded() / 1000 }).sorted()
        XCTAssertGreaterThan(ys.count, 25)
        for i in 1..<ys.count {
            XCTAssertEqual(ys[i] - ys[i - 1], 4.1, accuracy: 0.05)
        }
    }

    func testSpansCoverTheRowWithOverlappingShortStrokes() {
        var random = SeededRandom(seed: 3)
        for _ in 0..<50 {
            let spans = Flicks.spans(length: 300, strokeLength: 30...56, random: &random)
            XCTAssertEqual(spans.first?.lowerBound, 0)
            XCTAssertEqual(spans.last?.upperBound, 300)
            for span in spans { XCTAssertLessThanOrEqual(span.upperBound - span.lowerBound, 56) }
            for i in 1..<spans.count {
                XCTAssertLessThan(spans[i].lowerBound, spans[i - 1].upperBound, "neighbours overlap")
            }
        }
    }

    func testStrokeTapersAtBothEnds() throws {
        var random = SeededRandom(seed: 5)
        let flick = try XCTUnwrap(Flicks.stroke(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 100, y: 0),
                                                span: 0...48, bend: 1, style: style(edgeJitter: 0),
                                                random: &random))
        let half = flick.outline.count / 2
        let left = Array(flick.outline[..<half]), right = Array(flick.outline[half...].reversed())
        let widths = zip(left, right).map { hypot($0.x - $1.x, $0.y - $1.y) }
        XCTAssertEqual(widths.first!, 4.6 * 0.3, accuracy: 0.01)
        XCTAssertEqual(widths.last!, 4.6 * 0.3, accuracy: 0.01)
        XCTAssertEqual(widths.max()!, 4.6, accuracy: 0.05)
    }

    func testEveryStrokeInAShapeBendsTheSameWay() {
        let g = geometry(style: style(edgeJitter: 0))
        let sides = g.flicks.map { flick -> CGFloat in
            let half = flick.outline.count / 2
            let left = Array(flick.outline[..<half]), right = Array(flick.outline[half...].reversed())
            let centre = zip(left, right).map { CGPoint(x: ($0.x + $1.x) / 2, y: ($0.y + $1.y) / 2) }
            let a = centre.first!, b = centre.last!, m = centre[centre.count / 2]
            // Signed distance of the middle from the chord: the bend, free of the linear tilt.
            let cross = (b.x - a.x) * (m.y - a.y) - (b.y - a.y) * (m.x - a.x)
            return cross
        }
        XCTAssertGreaterThan(sides.count, 50)
        XCTAssertTrue(sides.allSatisfy { $0 > 0 } || sides.allSatisfy { $0 < 0 })
    }

    func testFlicksUseTheirOwnRandomStream() {
        // Changing the marker changes how much randomness the outline uses; the colouring must not move.
        XCTAssertEqual(geometry(marker: .standard).flicks, geometry(marker: .thin).flicks)
        XCTAssertNotEqual(geometry(seed: 1).flicks, geometry(seed: 2).flicks)
    }

    func testFlicksStayInsideTheShape() {
        let g = geometry()
        let path = CrayonGeometry.idealPath(kind: kind, in: rect.insetBy(dx: -3, dy: -3))
        let points = g.flicks.flatMap(\.outline)
        let outside = points.filter { !path.contains($0) }
        XCTAssertLessThan(Double(outside.count) / Double(points.count), 0.001)
    }
}
