import CoreGraphics
import CrayonKit
import XCTest

final class CrayonGeometryTests: XCTestCase {
    private let rect = CGRect(x: 0, y: 0, width: 400, height: 120)
    private let hachure = HachureStyle(degrees: -30)

    private func geometry(_ kind: CrayonShapeKind = .roundedRect(cornerRadius: 24),
                          rect: CGRect? = nil, seed: UInt32 = 7) -> CrayonGeometry {
        CrayonGeometry(kind: kind, in: rect ?? self.rect, seed: seed, marker: .standard, hachure: hachure)
    }

    /// Largest distance from any point of `points` to the closed ideal outline of `kind`.
    private func maxDeviation(_ points: [CGPoint], kind: CrayonShapeKind, rect: CGRect) -> CGFloat {
        let ideal = CrayonGeometry.idealOutline(kind: kind, in: rect, spacing: 1)
        return points.map { p in
            var best = CGFloat.greatestFiniteMagnitude
            for i in ideal.indices {
                best = min(best, distance(p, ideal[i], ideal[(i + 1) % ideal.count]))
            }
            return best
        }.max() ?? 0
    }

    private func distance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        let t = len2 == 0 ? 0 : max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }

    func testRandomMatchesReferenceSequence() {
        // Same Park–Miller LCG as Rough.js random.ts, seed 101 (values computed with Node).
        var random = SeededRandom(seed: 101)
        let expected = [0.0022702715359628201, 0.58827731246128678, 0.73414981877431273,
                        0.14590205485001206, 0.83808966493234038]
        for value in expected {
            XCTAssertEqual(random.next(), value, accuracy: 1e-15)
        }
    }

    func testSameSeedSameGeometry() {
        let a = geometry(), b = geometry()
        XCTAssertEqual(a.outline, b.outline)
        XCTAssertEqual(a.washOutline, b.washOutline)
        XCTAssertEqual(a.flicks, b.flicks)
    }

    func testDifferentSeedDifferentGeometry() {
        XCTAssertNotEqual(geometry(seed: 1).outline, geometry(seed: 2).outline)
    }

    func testOutlineStaysNearIdealShape() {
        let marker = MarkerStyle.standard
        let bound = marker.roughness + marker.bowing + 1
        let kinds: [CrayonShapeKind] = [
            .roundedRect(cornerRadius: 24), .capsule, .circle,
            .speechBubble(tailX: 0.3, tailHeight: 24),
        ]
        for kind in kinds {
            let r = kind == .circle ? CGRect(x: 0, y: 0, width: 160, height: 160) : rect
            let g = geometry(kind, rect: r)
            XCTAssertLessThanOrEqual(maxDeviation(g.outline, kind: kind, rect: r), bound, "\(kind)")
        }
    }

    func testStrokeJitterDoesNotScaleWithSize() {
        let marker = MarkerStyle.standard
        let small = CGRect(x: 0, y: 0, width: 200, height: 80)
        let large = CGRect(x: 0, y: 0, width: 1200, height: 80)
        let kind = CrayonShapeKind.capsule
        let smallMax = maxDeviation(geometry(kind, rect: small).outline, kind: kind, rect: small)
        let largeMax = maxDeviation(geometry(kind, rect: large).outline, kind: kind, rect: large)
        let bound = marker.roughness + marker.bowing + 1
        for value in [smallMax, largeMax] {
            XCTAssertGreaterThan(value, marker.roughness * 0.3)
            XCTAssertLessThanOrEqual(value, bound)
        }
    }


    func testSmallCircleHasEnoughSamplesToStayRound() {
        let small = CrayonGeometry(kind: .circle, in: CGRect(x: 0, y: 0, width: 44, height: 44), seed: 1,
                                   marker: MarkerStyle(width: 4, roughness: 0.6, bowing: 0.6), hachure: nil)
        XCTAssertGreaterThanOrEqual(small.outline.count, 24)
        XCTAssertEqual(CrayonGeometry.spacing(for: CGRect(x: 0, y: 0, width: 300, height: 300)), 12)
    }
}
