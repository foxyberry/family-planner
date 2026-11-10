import SwiftUI

/// What fills a crayon shape: a colour, hatched (crayon) or solid (paper).
public struct CrayonFill: Hashable, Sendable {
    public var color: Color
    /// Crayon hatching; nil means a solid fill like a sheet of paper.
    public var hachure: HachureStyle?

    public init(color: Color, hachure: HachureStyle?) {
        self.color = color
        self.hachure = hachure
    }

    /// Plain paper: a solid fill with no hatching.
    public static func paper(_ color: Color = .white) -> CrayonFill {
        CrayonFill(color: color, hachure: nil)
    }
}

/// A shape drawn like the design's crayon parts: light wash, crayon hatching, then a marker
/// line on top. Line widths are points, so they look the same at any size.
public struct CrayonSurface: View {
    let kind: CrayonShapeKind
    let fill: CrayonFill?
    let marker: MarkerStyle
    let markerColor: Color?
    let seed: UInt32
    @Environment(\.crayonOutline) private var outline

    /// `markerColor`: the line's colour; nil takes the environment's `crayonOutline`.
    public init(_ kind: CrayonShapeKind, fill: CrayonFill?, marker: MarkerStyle = .standard,
                markerColor: Color? = nil, seed: UInt32) {
        self.kind = kind
        self.fill = fill
        self.marker = marker
        self.markerColor = markerColor
        self.seed = seed
    }

    /// How far the line may wobble past the frame: the jitter (roughness + bowing), half the line
    /// and the closing overshoot. The canvas reaches this far out, because a Canvas clips what it
    /// draws to its bounds and cut every wobble flat at the frame (user, 2026-11-09: outlines cut).
    nonisolated static func bleed(_ marker: MarkerStyle) -> CGFloat {
        (marker.roughness + marker.bowing + marker.width / 2 + 2).rounded(.up)
    }

    public var body: some View {
        let bleed = Self.bleed(marker)
        let lineColor = markerColor ?? outline
        Canvas { context, size in
            // The part's own frame, inside the bleed; positions and the cache stay as they were.
            let frame = CGSize(width: max(size.width - 2 * bleed, 0), height: max(size.height - 2 * bleed, 0))
            context.translateBy(x: bleed, y: bleed)
            let g = Self.geometry(kind: kind, size: frame, fill: fill, marker: marker, seed: seed,
                                  cache: .shared)
            if let fill {
                let wash = Self.closedPath(g.washOutline)
                if let hachure = fill.hachure {
                    context.fill(wash, with: .color(fill.color.opacity(hachure.washOpacity)))
                    var strokes = Path()
                    for flick in g.flicks { strokes.addLines(flick.outline); strokes.closeSubpath() }
                    context.fill(strokes, with: .color(fill.color))
                } else {
                    context.fill(wash, with: .color(fill.color))
                }
            }
            var line = Path()
            line.addLines(g.outline)
            context.stroke(line, with: .color(lineColor),
                           style: StrokeStyle(lineWidth: marker.width, lineCap: .round, lineJoin: .round))
        }
        .padding(-bleed)
        .accessibilityHidden(true)
    }

    /// Geometry for a surface of `size`, inset by half the line width so the line's outer edge runs
    /// on the frame's edge: a part's visible edge is its frame (spec "A2 redlines": boxes are visible
    /// edges). The wobble may cross the edge by a point or two, like a real crayon.
    nonisolated static func geometry(kind: CrayonShapeKind, size: CGSize, fill: CrayonFill?, marker: MarkerStyle,
                         seed: UInt32, cache: GeometryCache) -> CrayonGeometry {
        let key = GeometryCache.Key(kind: kind, size: size, seed: seed, marker: marker, hachure: fill?.hachure)
        return cache.geometry(for: key) {
            let inset = marker.width / 2
            let rect = CGRect(x: 0, y: 0, width: CGFloat(key.width), height: CGFloat(key.height))
                .insetBy(dx: inset, dy: inset)
            return CrayonGeometry(kind: kind, in: rect, seed: seed, marker: marker, hachure: fill?.hachure)
        }
    }

    nonisolated private static func closedPath(_ points: [CGPoint]) -> Path {
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        return path
    }
}

extension View {
    /// Puts a crayon shape behind the view.
    public func crayonBackground(_ kind: CrayonShapeKind, fill: CrayonFill?, seed: UInt32,
                                 marker: MarkerStyle = .standard) -> some View {
        background(CrayonSurface(kind, fill: fill, marker: marker, seed: seed))
    }
}


extension EnvironmentValues {
    /// The default colour of crayon outlines: the marker grey. The design system sets one that
    /// turns chalk in dark mode.
    @Entry public var crayonOutline: Color = .init(white: 0.12)
}
