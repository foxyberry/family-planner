import CoreGraphics
import CrayonKit
import XCTest

final class CrayonGeometryTests: XCTestCase {
    private let rect = CGRect(x: 0, y: 0, width: 400, height: 120)
    private let hachure = HachureStyle(degrees: -30, gap: 5.5, weight: 2.6, washOpacity: 0.32)

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
        XCTAssertEqual(a.hachureLines, b.hachureLines)
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

    func testHachureSpacingMatchesGap() {
        let g = geometry(.roundedRect(cornerRadius: 8))
        // Project each segment midpoint onto the hachure normal and look at neighbour gaps.
        let radians = -30.0 * .pi / 180
        let normal = CGPoint(x: -sin(radians), y: cos(radians))
        let offsets = g.hachureLines
            .map { s in ((s.a.x + s.b.x) / 2) * normal.x + ((s.a.y + s.b.y) / 2) * normal.y }
            .sorted()
        var gaps: [CGFloat] = []
        for i in 1..<offsets.count where offsets[i] - offsets[i - 1] > 1 {
            gaps.append(offsets[i] - offsets[i - 1])
        }
        let median = gaps.sorted()[gaps.count / 2]
        XCTAssertEqual(median, hachure.gap, accuracy: 1)
    }

    func testHachureStaysMostlyInside() {
        let kind = CrayonShapeKind.roundedRect(cornerRadius: 24)
        let g = geometry(kind)
        let path = CrayonGeometry.idealPath(kind: kind, in: rect)
        let ends = g.hachureLines.flatMap { [$0.a, $0.b] }
        let outside = ends.filter { !path.contains($0) }
        XCTAssertLessThanOrEqual(maxDeviation(outside, kind: kind, rect: rect), 2)
    }
}
