import KitArt
import SwiftUI
import UIKit
import XCTest

@MainActor
final class KitArtTests: XCTestCase {
    /// Snapshot baselines are public: a public-only resolver must never pick a local private picture.
    func testPublicOnlyResolverNeverUsesPrivatePictures() {
        let publicOnly = BundledKitArt(includePrivate: false)
        for slot in KitSlot.allCases {
            XCTAssertEqual(publicOnly.source(for: slot), .public, "\(slot)")
        }
    }

    func testEverySlotHasAnAsset() {
        for slot in KitSlot.allCases {
            XCTAssertNotNil(BundledKitArt.publicImage(for: slot), "\(slot.rawValue) has no picture")
        }
    }

    func testAssetsArePreservedVectors() throws {
        // Draw the picture at 1024 pt directly and blown up 4x from 256 pt. The bundled bitmaps
        // top out at 720 px, so only a preserved vector stays sharp at 1024 pt; sharp edges show
        // up as much larger pixel-to-pixel differences than the blurry blow-up.
        let direct = try XCTUnwrap(render(KitIcon(.busDouble, size: 1024), size: 1024))
        let small = try XCTUnwrap(render(KitIcon(.busDouble, size: 256), size: 256))
        let blownUp = try XCTUnwrap(scale(small, to: 1024))
        XCTAssertGreaterThan(edgeEnergy(direct), edgeEnergy(blownUp) * 1.5)
    }

    func testResolverCanBeReplaced() throws {
        let icon = KitIcon(.star, size: 64).environment(\.kitArt, SolidRedArt())
        let image = try XCTUnwrap(render(icon, size: 64))
        let center = pixel(image, x: 32, y: 32)
        XCTAssertGreaterThan(center.red, 0.9)
        XCTAssertLessThan(center.green, 0.1)
    }

    // MARK: - Helpers

    private struct SolidRedArt: KitArtResolving {
        func image(for slot: KitSlot) -> Image {
            Image(uiImage: UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
                UIColor.red.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
            })
        }
    }

    private func render(_ view: some View, size: CGFloat) -> CGImage? {
        let renderer = ImageRenderer(content: view.frame(width: size, height: size))
        renderer.scale = 1
        return renderer.cgImage
    }

    private func scale(_ image: CGImage, to size: Int) -> CGImage? {
        let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.interpolationQuality = .high
        context?.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
        return context?.makeImage()
    }

    private func rgba(_ image: CGImage) -> [UInt8] {
        let w = image.width, h = image.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let context = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return data
    }

    /// Mean squared difference between neighbouring pixels (all channels). Squaring matters:
    /// a blurred edge spreads the same total step over more pixels, which lowers the sum of
    /// squares but would not change a sum of absolute values.
    private func edgeEnergy(_ image: CGImage) -> Double {
        let data = rgba(image), w = image.width, h = image.height
        var total = 0
        for y in 0..<(h - 1) {
            for x in 0..<(w - 1) {
                let i = (y * w + x) * 4, right = i + 4, below = i + w * 4
                for c in 0..<4 {
                    let dx = Int(data[i + c]) - Int(data[right + c])
                    let dy = Int(data[i + c]) - Int(data[below + c])
                    total += dx * dx + dy * dy
                }
            }
        }
        return Double(total) / Double(w * h)
    }

    private func pixel(_ image: CGImage, x: Int, y: Int) -> (red: Double, green: Double) {
        let data = rgba(image)
        let i = (y * image.width + x) * 4
        return (Double(data[i]) / 255, Double(data[i + 1]) / 255)
    }
}
