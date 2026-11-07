import CoreGraphics
import SwiftUI
@testable import CrayonKit
import XCTest

final class CrayonSurfaceTests: XCTestCase {
    private let sky = CrayonFill(color: .blue, hachure: HachureStyle(degrees: -30))

    private func geometry(width: CGFloat, fill: CrayonFill?, cache: GeometryCache) -> CrayonGeometry {
        CrayonSurface.geometry(kind: .capsule, size: CGSize(width: width, height: 80), fill: fill,
                               marker: .standard, seed: 3, cache: cache)
    }

    func testGeometryIsCachedPerSize() {
        let cache = GeometryCache()
        _ = geometry(width: 200, fill: sky, cache: cache)
        _ = geometry(width: 200, fill: sky, cache: cache)
        XCTAssertEqual(cache.makeCount, 1)
        _ = geometry(width: 201, fill: sky, cache: cache)
        XCTAssertEqual(cache.makeCount, 2)
    }

    func testSubpixelSizesShareCache() {
        let cache = GeometryCache()
        _ = geometry(width: 200.2, fill: sky, cache: cache)
        _ = geometry(width: 200.4, fill: sky, cache: cache)
        XCTAssertEqual(cache.makeCount, 1)
    }

    /// A morning countdown redraws its row every second; one minute of redraws at the same size
    /// must reuse the crayon geometry built on the first draw (Review Focus 2).
    @MainActor
    func testCountdownRedrawsReuseGeometry() {
        func draw(_ seconds: Int) {
            let row = Text("\(seconds / 60):\(String(format: "%02d", seconds % 60)) left")
                .frame(width: 420, height: 104)
                .crayonBackground(.roundedRect(cornerRadius: 24), fill: sky, seed: 9_001)
            _ = ImageRenderer(content: row).cgImage
        }
        let beforeFirstDraw = GeometryCache.shared.makeCount
        draw(600)
        let afterFirstDraw = GeometryCache.shared.makeCount
        XCTAssertEqual(afterFirstDraw, beforeFirstDraw + 1, "the first draw must build the geometry once")
        for second in (540..<600).reversed() { draw(second) }
        XCTAssertEqual(GeometryCache.shared.makeCount, afterFirstDraw)
    }

    func testPaperFillHasNoHachure() {
        let g = geometry(width: 300, fill: .paper(), cache: GeometryCache())
        XCTAssertTrue(g.flicks.isEmpty)
        XCTAssertFalse(g.outline.isEmpty)
    }
}
