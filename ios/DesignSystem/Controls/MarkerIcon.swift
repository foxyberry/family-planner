import CrayonKit
import SwiftUI

/// A `MarkerGlyph` drawn in marker (5 pt at the 48 box, fixed when resized), round caps and joins.
/// Sizes: back chevron 40 in a `RoundButton`, row-end chevron 28 (soft), arrows 32 after a label,
/// plus / minus 40.
public struct MarkerIcon: View {
    private let glyph: MarkerGlyph
    private let size: CGFloat
    private let color: Color

    public init(_ glyph: MarkerGlyph, size: CGFloat, color: Color = CrayonColor.ink) {
        self.glyph = glyph
        self.size = size
        self.color = color
    }

    public var body: some View {
        Canvas { context, _ in  // bleed-ok: glyphs keep 6 of 48 clear, more than half a line plus the wobble
            var path = Path()
            for stroke in glyph.path(size: size, seed: CrayonStyle.Seed.glyph + UInt32(glyph.hashSeed)) {
                path.addLines(stroke)
            }
            context.stroke(path, with: .color(color),
                           style: StrokeStyle(lineWidth: max(3, 5 * size / 48), lineCap: .round, lineJoin: .round))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private extension MarkerGlyph {
    var hashSeed: Int { MarkerGlyph.allCases.firstIndex(of: self) ?? 0 }
}
