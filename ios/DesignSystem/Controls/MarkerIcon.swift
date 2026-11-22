import CrayonKit
import SwiftUI

/// A `MarkerGlyph` drawn in marker (5 at the 48 box, never under 3, on the board; × s on screen),
/// round caps and joins. Sizes (board): back chevron 40 in a `RoundButton`, row-end chevron 28
/// (soft), arrows 32 after a label, plus / minus 40. `size` is the screen size (board × s).
public struct MarkerIcon: View {
    private let glyph: MarkerGlyph
    private let size: CGFloat
    private let color: Color
    private let line: CGFloat?
    @Environment(\.sizing) private var sizing

    /// `line`: the board line width when the spec names one (home's mission "›" 6.5); nil scales 5 at 48.
    public init(_ glyph: MarkerGlyph, size: CGFloat, color: Color = CrayonColor.ink, line: CGFloat? = nil) {
        self.glyph = glyph
        self.size = size
        self.color = color
        self.line = line
    }

    public var body: some View {
        let lineWidth = if let line { line } else { max(3, 5 * size / sizing.s / 48) }
        return Canvas { context, _ in  // bleed-ok: glyphs keep 6 of 48 clear, more than half a line plus the wobble
            var path = Path()
            for stroke in glyph.path(size: size, seed: CrayonStyle.Seed.glyph + UInt32(glyph.seedIndex)) {
                path.addLines(stroke)
            }
            context.stroke(path, with: .color(color),
                           style: StrokeStyle(lineWidth: lineWidth * sizing.s, lineCap: .round,
                                              lineJoin: .round))
        }
        .frame(width: size, height: size)
    }
}
