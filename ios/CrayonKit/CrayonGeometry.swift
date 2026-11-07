import CoreGraphics

/// Everything needed to draw one crayon shape: the marker line, the soft wash edge and the
/// colouring strokes. Pure values, computed once per (shape, size, seed, style).
public struct CrayonGeometry: Equatable, Sendable {
    /// Marker line, drawn in one stroke (closed, with a small overshoot).
    public let outline: [CGPoint]
    /// Wobbly edge of the light colour wash under the hatching.
    public let washOutline: [CGPoint]
    /// Colouring strokes; empty when there is no hachure.
    public let flicks: [CrayonFlick]

    /// Distance between outline samples, in points.
    static let sampleSpacing: CGFloat = 12

    public init(kind: CrayonShapeKind, in rect: CGRect, seed: UInt32,
                marker: MarkerStyle, hachure: HachureStyle?) {
        var random = SeededRandom(seed: seed)
        let ideal = Self.idealOutline(kind: kind, in: rect, spacing: Self.sampleSpacing)
        outline = Self.jitter(ideal, roughness: marker.roughness, bowing: marker.bowing, random: &random)
        washOutline = Self.jitter(ideal, roughness: marker.roughness * 0.6, bowing: marker.bowing * 0.6,
                                  random: &random)
        if let hachure {
            // Its own random stream, so the colouring does not move when the outline style changes.
            var flickRandom = SeededRandom(seed: seed ^ 0x5F37_59DF)
            let fine = Self.idealOutline(kind: kind, in: rect, spacing: 2)
            flicks = Flicks.flicks(polygon: fine, style: hachure, random: &flickRandom)
        } else {
            flicks = []
        }
    }
}
