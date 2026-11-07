import CoreGraphics
import Foundation

enum Hachure {
    /// Parallel crayon strokes `gap` apart at `degrees`, clipped to the closed `polygon`.
    /// Each end may stop up to 1 pt short or run up to 1.5 pt past the edge, like real crayon.
    static func lines(polygon: [CGPoint], style: HachureStyle, random: inout SeededRandom) -> [CrayonSegment] {
        guard polygon.count > 2, style.gap > 0 else { return [] }
        let radians = style.degrees * .pi / 180
        let center = CGPoint(
            x: (polygon.map(\.x).min()! + polygon.map(\.x).max()!) / 2,
            y: (polygon.map(\.y).min()! + polygon.map(\.y).max()!) / 2
        )
        // Rotate so the hatch direction becomes horizontal, scan, rotate back.
        let flat = polygon.map { rotate($0, by: -radians, around: center) }
        let minY = flat.map(\.y).min()!, maxY = flat.map(\.y).max()!
        var segments: [CrayonSegment] = []
        var y = minY + style.gap / 2
        while y < maxY {
            var xs: [CGFloat] = []
            for i in flat.indices {
                let a = flat[i], b = flat[(i + 1) % flat.count]
                if (a.y <= y && b.y > y) || (b.y <= y && a.y > y) {
                    xs.append(a.x + (y - a.y) / (b.y - a.y) * (b.x - a.x))
                }
            }
            xs.sort()
            var i = 0
            while i + 1 < xs.count {
                let start = xs[i] - CGFloat(random.next() * 2.5 - 1.0)
                let end = xs[i + 1] + CGFloat(random.next() * 2.5 - 1.0)
                let a = CGPoint(x: start, y: y + CGFloat(random.signed()) * 0.5)
                let b = CGPoint(x: end, y: y + CGFloat(random.signed()) * 0.5)
                if end - start > 2 {
                    segments.append(CrayonSegment(rotate(a, by: radians, around: center),
                                                  rotate(b, by: radians, around: center)))
                }
                i += 2
            }
            y += style.gap
        }
        return segments
    }

    private static func rotate(_ p: CGPoint, by angle: Double, around c: CGPoint) -> CGPoint {
        let s = CGFloat(sin(angle)), co = CGFloat(cos(angle))
        let x = p.x - c.x, y = p.y - c.y
        return CGPoint(x: c.x + x * co - y * s, y: c.y + x * s + y * co)
    }
}
