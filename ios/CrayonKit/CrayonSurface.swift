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
    let markerColor: Color
    let seed: UInt32

    public init(_ kind: CrayonShapeKind, fill: CrayonFill?, marker: MarkerStyle = .standard,
                markerColor: Color = .init(white: 0.12), seed: UInt32) {
        self.kind = kind
        self.fill = fill
        self.marker = marker
        self.markerColor = markerColor
        self.seed = seed
    }

    public var body: some View {
        Canvas { context, size in
            let g = Self.geometry(kind: kind, size: size, fill: fill, marker: marker, seed: seed,
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
            context.stroke(line, with: .color(markerColor),
                           style: StrokeStyle(lineWidth: marker.width, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }

    /// Geometry for a surface of `size`, inset so the wobble and line never get clipped.
    nonisolated static func geometry(kind: CrayonShapeKind, size: CGSize, fill: CrayonFill?, marker: MarkerStyle,
                         seed: UInt32, cache: GeometryCache) -> CrayonGeometry {
        let key = GeometryCache.Key(kind: kind, size: size, seed: seed, marker: marker, hachure: fill?.hachure)
        return cache.geometry(for: key) {
            let inset = marker.width / 2 + marker.roughness + marker.bowing
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
