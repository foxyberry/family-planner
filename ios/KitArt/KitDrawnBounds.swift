import Synchronization
import UIKit

extension BundledKitArt {
    /// Where the picture's drawing ends, as a share of its square box from the top (kit pictures
    /// carry some empty margin): 1 = the box bottom. Used to stand a picture on a stem by its drawn
    /// bottom (spec A2-MVP "Way strip"). Measured once per slot from the picture the app shows
    /// (the private override when there is one), then cached.
    public func drawnBottom(for slot: KitSlot) -> CGFloat {
        let key = "\(slot.rawValue)|\(includePrivate)"
        if let cached = KitDrawnBounds.cache.withLock({ $0[key] }) { return cached }
        let picture: UIImage? = switch source(for: slot) {
        case .private: Self.privateImage(for: slot)
        case .public: Self.publicImage(for: slot)
        case .missing: nil
        }
        let value = picture.map(KitDrawnBounds.drawnBottom(of:)) ?? 1
        KitDrawnBounds.cache.withLock { $0[key] = value }
        return value
    }
}

enum KitDrawnBounds {
    static let cache = Mutex<[String: CGFloat]>([:])
    static let side = 120

    /// The lowest row with ink, drawn aspect-fit into a `side` square, as a share of the square.
    static func drawnBottom(of image: UIImage) -> CGFloat {
        let side = Self.side
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                          bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            let size = image.size, fit = CGFloat(side) / max(size.width, size.height, 1)
            let rect = CGRect(x: (CGFloat(side) - size.width * fit) / 2, y: (CGFloat(side) - size.height * fit) / 2,
                              width: size.width * fit, height: size.height * fit)
            UIGraphicsPushContext(context)
            // UIKit draws top-down; flip the bitmap context so memory row 0 is the top.
            context.translateBy(x: 0, y: CGFloat(side))
            context.scaleBy(x: 1, y: -1)
            image.draw(in: rect)
            UIGraphicsPopContext()
            return true
        }
        guard drawn else { return 1 }
        for row in stride(from: side - 1, through: 0, by: -1) {
            let start = row * side * 4
            if stride(from: start + 3, to: start + side * 4, by: 4).contains(where: { pixels[$0] > 24 }) {
                return CGFloat(row + 1) / CGFloat(side)
            }
        }
        return 1
    }
}
