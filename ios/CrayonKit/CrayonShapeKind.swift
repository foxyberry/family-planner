import CoreGraphics

/// The shapes components are drawn with.
public enum CrayonShapeKind: Hashable, Sendable {
    case roundedRect(cornerRadius: CGFloat)
    case capsule
    case circle
    /// A rounded box with a tail at the bottom. `tailX` is a 0...1 fraction of the width.
    case speechBubble(tailX: CGFloat, tailHeight: CGFloat)
    /// A pie slice of the circle that fits the rect, clockwise from 12 o'clock. `endDegrees` may pass
    /// 360 for a slice across the top (a night that runs past midnight).
    case sector(startDegrees: Double, endDegrees: Double)
}

/// Marker line settings. Design defaults: roughness 1.2, bowing 1.4, width 4.
public struct MarkerStyle: Hashable, Sendable {
    public var width: CGFloat
    public var roughness: CGFloat
    public var bowing: CGFloat

    public init(width: CGFloat, roughness: CGFloat, bowing: CGFloat) {
        self.width = width
        self.roughness = roughness
        self.bowing = bowing
    }

    public static let standard = MarkerStyle(width: 4, roughness: 1.2, bowing: 1.4)
    public static let thin = MarkerStyle(width: 3.5, roughness: 1.2, bowing: 1.4)
}

/// Crayon colouring settings (design ST-13, "wrist flicks"): rows `gap` apart at `degrees`, each
/// cut into short strokes that bend one way, taper at both ends and overlap their neighbours.
public struct HachureStyle: Hashable, Sendable {
    /// Direction of the rows in degrees (screen coordinates, y down).
    public var degrees: Double
    /// Distance between rows.
    public var gap: CGFloat
    /// Widest point of a stroke.
    public var weight: CGFloat
    public var washOpacity: Double
    /// Length of one stroke before it is clipped to the row.
    public var strokeLength: ClosedRange<CGFloat>
    /// Radius of a stroke's bend (sagitta = chord² / (8 · radius)).
    public var bendRadius: CGFloat
    /// Stroke width at its ends, as a share of `weight`.
    public var taper: CGFloat
    /// Waxy edge: each side moves by up to ± half this share of its width.
    public var edgeJitter: CGFloat
    /// The whole shape's rows tilt by up to ± this many degrees.
    public var angleJitter: Double

    public init(degrees: Double, gap: CGFloat = 4.1, weight: CGFloat = 4.6, washOpacity: Double = 0.32,
                strokeLength: ClosedRange<CGFloat> = 30...56, bendRadius: CGFloat = 120, taper: CGFloat = 0.3,
                edgeJitter: CGFloat = 0.5, angleJitter: Double = 4) {
        self.degrees = degrees
        self.gap = gap
        self.weight = weight
        self.washOpacity = washOpacity
        self.strokeLength = strokeLength
        self.bendRadius = bendRadius
        self.taper = taper
        self.edgeJitter = edgeJitter
        self.angleJitter = angleJitter
    }
}

/// One colouring stroke, as a filled outline (left edge, then the right edge back).
public struct CrayonFlick: Hashable, Sendable {
    public let outline: [CGPoint]
}

/// One hatch stroke.
public struct CrayonSegment: Hashable, Sendable {
    public let a: CGPoint
    public let b: CGPoint

    public init(_ a: CGPoint, _ b: CGPoint) {
        self.a = a
        self.b = b
    }
}
