import CrayonKit
import SwiftUI

/// The grown-up lock picture (S4 "Grown-up lock"): a yellow crayon body under the marker
/// `MarkerGlyph.lock`. Drawn in code: the kit has no lock slot.
public struct LockMark: View {
    private let size: CGFloat?
    @Environment(\.sizing) private var sizing

    /// `size`: screen points; nil is the board's 56 × s.
    public init(size: CGFloat? = nil) {
        self.size = size
    }

    public var body: some View {
        let size = if let size { size } else { sizing(56) }
        let scale = size / 48
        let body = MarkerGlyph.lockBody
        ZStack(alignment: .topLeading) {
            // The corner radius is in board units (the surface scales it).
            CrayonSurface(.roundedRect(cornerRadius: 4 * scale / sizing.s), fill: CrayonStyle.yellowSlider, marker: .thin,
                          markerColor: .clear, seed: CrayonStyle.Seed.glyph + 50)
                .frame(width: body.width * scale, height: body.height * scale)
                .offset(x: body.minX * scale, y: body.minY * scale)
            MarkerIcon(.lock, size: size)
        }
        .frame(width: size, height: size)
    }
}
