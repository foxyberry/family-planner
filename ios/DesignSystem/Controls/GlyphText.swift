import CrayonKit
import SwiftUI

/// Copy with a marker glyph inside the sentence ("Drag ≡ to change the order"): `format` holds one
/// `%@` where the glyph goes, drawn at the text size in the text colour. Playpen Sans has no ≡ or
/// arrows, so they are never characters in copy.
public struct GlyphText: View {
    private let before: String
    private let after: String
    private let glyph: MarkerGlyph
    private let type: CrayonType
    private let color: Color

    public init(_ format: String, glyph: MarkerGlyph, type: CrayonType = .caption, color: Color = CrayonColor.ink) {
        let parts = format.components(separatedBy: "%@")
        before = parts[0] // components(separatedBy:) always returns at least one part
        after = parts.dropFirst().joined(separator: " ")
        self.glyph = glyph
        self.type = type
        self.color = color
    }

    public var body: some View {
        let size = type.size
        let strokes = glyph.path(size: size, seed: CrayonStyle.Seed.glyph + UInt32(glyph.seedIndex))
        let image = Image(size: CGSize(width: size, height: size)) { context in
            var path = Path()
            for stroke in strokes { path.addLines(stroke) }
            context.stroke(path, with: .color(color),
                           style: StrokeStyle(lineWidth: max(2.5, 5 * size / 48), lineCap: .round, lineJoin: .round))
        }
        Text("\(Text(verbatim: before))\(Text(image).baselineOffset(-size * 0.2))\(Text(verbatim: after))")
            .crayonType(type)
            .foregroundStyle(color)
            .accessibilityLabel(Text(verbatim: before + after))
    }
}
