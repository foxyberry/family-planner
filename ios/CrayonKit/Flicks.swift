import CoreGraphics
import Foundation

/// Wrist-flick colouring (design ST-13). A child colours with the wrist fixed and snaps each
/// stroke, so strokes are short, bend a little (all the same way in one shape), are thin at both
/// ends, overlap their neighbours and have a waxy edge.
enum Flicks {
    static func flicks(polygon: [CGPoint], style: HachureStyle, random: inout SeededRandom) -> [CrayonFlick] {
        guard polygon.count > 2, style.gap > 0 else { return [] }
        let tilt = random.signed() * style.angleJitter
        let bend: CGFloat = random.next() < 0.5 ? 1 : -1   // one hand, one bend direction per shape
        var result: [CrayonFlick] = []
        for row in rows(polygon: polygon, degrees: style.degrees + tilt, gap: style.gap) {
            let length = hypot(row.b.x - row.a.x, row.b.y - row.a.y)
            guard length >= 3 else { continue }
            for span in spans(length: length, strokeLength: style.strokeLength, random: &random) {
                if let flick = stroke(from: row.a, to: row.b, span: span, bend: bend, style: style, random: &random) {
                    result.append(flick)
                }
            }
        }
        return result
    }

    /// Scanline rows `gap` apart at `degrees`, clipped to the closed `polygon`. Steps by the gap
    /// itself (the hachure-fill port pitfall: `iteration % gap` drops most rows for a fractional gap).
    static func rows(polygon: [CGPoint], degrees: Double, gap: CGFloat) -> [CrayonSegment] {
        let radians = degrees * .pi / 180
        let center = CGPoint(
            x: (polygon.map(\.x).min()! + polygon.map(\.x).max()!) / 2,
            y: (polygon.map(\.y).min()! + polygon.map(\.y).max()!) / 2
        )
        // Rotate so the rows become horizontal, scan, rotate back.
        let flat = polygon.map { rotate($0, by: -radians, around: center) }
        let minY = flat.map(\.y).min()!, maxY = flat.map(\.y).max()!
        var rows: [CrayonSegment] = []
        var y = minY + gap / 2
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
                rows.append(CrayonSegment(rotate(CGPoint(x: xs[i], y: y), by: radians, around: center),
                                          rotate(CGPoint(x: xs[i + 1], y: y), by: radians, around: center)))
                i += 2
            }
            y += gap
        }
        return rows
    }

    /// Where the strokes of one row start and end: the first starts a little before the row,
    /// each advances by 72–90 % of its length so neighbours overlap, all clipped to the row.
    static func spans(length: CGFloat, strokeLength: ClosedRange<CGFloat>,
                      random: inout SeededRandom) -> [ClosedRange<CGFloat>] {
        var spans: [ClosedRange<CGFloat>] = []
        var t = -CGFloat(random.next()) * strokeLength.lowerBound * 0.4
        while t < length {
            let l = strokeLength.lowerBound + CGFloat(random.next()) * (strokeLength.upperBound - strokeLength.lowerBound)
            let start = max(0, t), end = min(length, t + l)
            if end - start > 3 { spans.append(start...end) }
            t += l * (0.72 + CGFloat(random.next()) * 0.18)
        }
        return spans
    }

    /// One stroke along the row a→b over `span`: the centre line bends by the sagitta plus a small
    /// tilt, the width swells from `taper` to full in the middle, each side jittered for wax.
    static func stroke(from a: CGPoint, to b: CGPoint, span: ClosedRange<CGFloat>, bend: CGFloat,
                       style: HachureStyle, random: inout SeededRandom) -> CrayonFlick? {
        let length = hypot(b.x - a.x, b.y - a.y)
        let chord = span.upperBound - span.lowerBound
        guard length > 0, chord > 3 else { return nil }
        let ux = (b.x - a.x) / length, uy = (b.y - a.y) / length
        let nx = -uy * bend, ny = ux * bend
        let sag = chord * chord / (8 * style.bendRadius)
        let tilt = CGFloat(random.signed()) * 0.05
        let n = max(5, Int((chord / 3).rounded()))
        var left: [CGPoint] = [], right: [CGPoint] = []
        for k in 0...n {
            let u = CGFloat(k) / CGFloat(n)
            let along = span.lowerBound + chord * u
            let off = sag * 4 * u * (1 - u) + (u - 0.5) * chord * tilt
            let cx = a.x + ux * along + nx * off, cy = a.y + uy * along + ny * off
            let half = style.weight / 2 * (style.taper + (1 - style.taper) * sin(.pi * u))
            let jl = 1 + CGFloat(random.next() - 0.5) * style.edgeJitter
            let jr = 1 + CGFloat(random.next() - 0.5) * style.edgeJitter
            left.append(CGPoint(x: cx + nx * half * jl, y: cy + ny * half * jl))
            right.append(CGPoint(x: cx - nx * half * jr, y: cy - ny * half * jr))
        }
        return CrayonFlick(outline: left + right.reversed())
    }

    private static func rotate(_ p: CGPoint, by angle: Double, around c: CGPoint) -> CGPoint {
        let s = CGFloat(sin(angle)), co = CGFloat(cos(angle))
        let x = p.x - c.x, y = p.y - c.y
        return CGPoint(x: c.x + x * co - y * s, y: c.y + x * s + y * co)
    }
}
