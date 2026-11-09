import CrayonKit
import SwiftUI

/// The grown-up lock picture (S4 "Grown-up lock"): a yellow crayon body under the marker
/// `MarkerGlyph.lock`. Drawn in code: the kit has no lock slot.
public struct LockMark: View {
    private let size: CGFloat

    public init(size: CGFloat = 56) {
        self.size = size
    }

    public var body: some View {
        let scale = size / 48
        let body = MarkerGlyph.lockBody
        ZStack(alignment: .topLeading) {
            CrayonSurface(.roundedRect(cornerRadius: 4 * scale), fill: CrayonStyle.yellowSlider, marker: .thin,
                          markerColor: .clear, seed: CrayonStyle.Seed.glyph + 50)
                .frame(width: body.width * scale, height: body.height * scale)
                .offset(x: body.minX * scale, y: body.minY * scale)
            MarkerIcon(.lock, size: size)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
