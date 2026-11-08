import DesignSystem
import SwiftUI
import XCTest

/// Spec "Status bar" and "Board = screen": the band y 0–24 stays empty on the 13" and the 12.9",
/// even when a screen's content is taller than the board (the 2026-11-08 bug centred it upwards).
@MainActor
final class BoardFrameTests: XCTestCase {
    private let sizes = [CGSize(width: 1376, height: 1032), CGSize(width: 1366, height: 1024)]

    func testStatusBandStaysEmptyOnBothIPads() throws {
        for size in sizes {
            let rows = try inkRows(of: KidFullScreen { Self.tallContent }, size: size)
            XCTAssertTrue(rows.prefix(Int(BoardMetrics.statusBand)).allSatisfy { !$0 }, "ink in the band at \(size)")
            // The content starts at board y 36 (scaled), so it is drawn just below the band.
            let first = try XCTUnwrap(rows.firstIndex(of: true))
            XCTAssertEqual(CGFloat(first), 36 * BoardMetrics.scale(for: size), accuracy: 1.5)
        }
    }

    func testBoardScalesToTheSmallerIPad() {
        XCTAssertEqual(BoardMetrics.scale(for: CGSize(width: 1376, height: 1032)), 1)
        // The height is the tighter side: 1024 / 1032.
        XCTAssertEqual(BoardMetrics.scale(for: CGSize(width: 1366, height: 1024)), 1024.0 / 1032, accuracy: 0.0001)
    }

    /// Ink from y 36 down, far past the board's bottom.
    private static var tallContent: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: 36)
            Color.black.frame(width: 200, height: 1400)
        }
    }

    /// For each pixel row, whether it holds any dark pixel.
    private func inkRows(of view: some View, size: CGSize) throws -> [Bool] {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                                              bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        // A bitmap context keeps the image's top row first in memory.
        return (0..<height).map { row in
            let offset = row * width * 4
            return stride(from: offset, to: offset + width * 4, by: 4).contains { pixels[$0] < 60 && pixels[$0 + 3] > 200 }
        }
    }
}
