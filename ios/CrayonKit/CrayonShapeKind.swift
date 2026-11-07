import CoreGraphics

/// The shapes components are drawn with.
public enum CrayonShapeKind: Hashable, Sendable {
    case roundedRect(cornerRadius: CGFloat)
    case capsule
    case circle
    /// A rounded box with a tail at the bottom. `tailX` is a 0...1 fraction of the width.
    case speechBubble(tailX: CGFloat, tailHeight: CGFloat)
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

/// Crayon hatching settings. Design defaults: gap 5.5, weight 2.6, wash 0.32.
public struct HachureStyle: Hashable, Sendable {
    /// Direction of the hatch lines in degrees (screen coordinates, y down).
    public var degrees: Double
    public var gap: CGFloat
    public var weight: CGFloat
    public var washOpacity: Double

    public init(degrees: Double, gap: CGFloat = 5.5, weight: CGFloat = 2.6, washOpacity: Double = 0.32) {
        self.degrees = degrees
        self.gap = gap
        self.weight = weight
        self.washOpacity = washOpacity
    }
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
