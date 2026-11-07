import UIKit

/// One short line about how two pictures differ. CI prints only this line for a failed
/// snapshot: CI logs of this public repo are public and keep no artifacts, so the diff image
/// itself is written only on a local run (SNAPSHOT_ARTIFACTS points at the git-ignored __Diffs__).
enum SnapshotDiff {
    static func summary(reference: UIImage, actual: UIImage) -> String {
        guard let old = pixels(reference), let new = pixels(actual) else { return "pictures could not be read" }
        guard old.width == new.width, old.height == new.height else {
            return "size changed from \(old.width)x\(old.height) to \(new.width)x\(new.height) px"
        }
        var different = 0
        for index in stride(from: 0, to: old.bytes.count, by: 4)
            where old.bytes[index ..< index + 4] != new.bytes[index ..< index + 4] {
            different += 1
        }
        let percent = Double(different) / Double(old.width * old.height) * 100
        return String(format: "%.2f%% of pixels differ", percent)
    }

    /// Decodes into RGBA8 so both pictures are compared in the same pixel format.
    private static func pixels(_ image: UIImage) -> (width: Int, height: Int, bytes: [UInt8])? {
        guard let cgImage = image.cgImage else { return nil }
        let width = cgImage.width, height = cgImage.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drawn ? (width, height, bytes) : nil
    }
}
