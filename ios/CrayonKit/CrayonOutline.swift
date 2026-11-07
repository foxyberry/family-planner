import CoreGraphics

extension CrayonGeometry {
    /// The exact (un-jittered) outline of `kind` in `rect`.
    public static func idealPath(kind: CrayonShapeKind, in rect: CGRect) -> CGPath {
        switch kind {
        case let .roundedRect(cornerRadius):
            let r = min(cornerRadius, rect.width / 2, rect.height / 2)
            return CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
        case .capsule:
            let r = min(rect.width, rect.height) / 2
            return CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil)
        case .circle:
            return CGPath(ellipseIn: rect, transform: nil)
        case let .speechBubble(tailX, tailHeight):
            return speechBubblePath(rect: rect, tailX: tailX, tailHeight: tailHeight)
        }
    }

    /// Points along the ideal outline, `spacing` points apart (fixed length, not a fraction of
    /// the size, so large and small shapes wobble alike).
    public static func idealOutline(kind: CrayonShapeKind, in rect: CGRect, spacing: CGFloat) -> [CGPoint] {
        resample(polyline(of: idealPath(kind: kind, in: rect)), spacing: spacing)
    }

    private static func speechBubblePath(rect: CGRect, tailX: CGFloat, tailHeight: CGFloat) -> CGPath {
        let bodyBottom = rect.maxY - tailHeight
        let r = min(24, (bodyBottom - rect.minY) / 2, rect.width / 2)
        let halfBase = min(16, rect.width * 0.08)
        let tip = min(max(rect.minX + tailX * rect.width, rect.minX + r + halfBase), rect.maxX - r - halfBase)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
                    tangent2End: CGPoint(x: rect.maxX, y: bodyBottom), radius: r)
        path.addArc(tangent1End: CGPoint(x: rect.maxX, y: bodyBottom),
                    tangent2End: CGPoint(x: rect.minX, y: bodyBottom), radius: r)
        path.addLine(to: CGPoint(x: tip + halfBase, y: bodyBottom))
        path.addLine(to: CGPoint(x: tip, y: rect.maxY))
        path.addLine(to: CGPoint(x: tip - halfBase, y: bodyBottom))
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: bodyBottom),
                    tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: r)
        path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY),
                    tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: r)
        path.closeSubpath()
        return path
    }

    /// Vertices of the first closed subpath after flattening curves.
    private static func polyline(of path: CGPath) -> [CGPoint] {
        var points: [CGPoint] = []
        path.flattened(threshold: 0.2).applyWithBlock { element in
            switch element.pointee.type {
            case .moveToPoint where points.isEmpty, .addLineToPoint:
                points.append(element.pointee.points[0])
            default:
                break
            }
        }
        if let first = points.first, let last = points.last, hypot(first.x - last.x, first.y - last.y) < 0.01 {
            points.removeLast()
        }
        return points
    }

    /// Walks the closed polyline and emits a point every `spacing` along its length.
    private static func resample(_ points: [CGPoint], spacing: CGFloat) -> [CGPoint] {
        guard points.count > 1 else { return points }
        var result = [points[0]]
        var carried: CGFloat = 0
        for i in points.indices {
            let a = points[i], b = points[(i + 1) % points.count]
            let length = hypot(b.x - a.x, b.y - a.y)
            guard length > 0 else { continue }
            var t = spacing - carried
            while t < length {
                result.append(CGPoint(x: a.x + (b.x - a.x) * t / length, y: a.y + (b.y - a.y) * t / length))
                t += spacing
            }
            carried = length - (t - spacing)
        }
        if let last = result.last, hypot(last.x - points[0].x, last.y - points[0].y) < spacing * 0.5 {
            result.removeLast()
        }
        return result
    }

    /// Pushes each point along its normal by smooth noise (roughness) plus a slow bend (bowing),
    /// then runs 1.5 pt past the start like a marker closing a shape in one stroke.
    static func jitter(_ points: [CGPoint], roughness: CGFloat, bowing: CGFloat,
                       random: inout SeededRandom) -> [CGPoint] {
        let n = points.count
        guard n > 2 else { return points }
        let rough = smoothNoise(count: n, every: 3, amplitude: roughness, random: &random)
        let bow = smoothNoise(count: n, every: 10, amplitude: bowing, random: &random)
        var result: [CGPoint] = []
        result.reserveCapacity(n + 1)
        for i in 0..<n {
            let prev = points[(i - 1 + n) % n], next = points[(i + 1) % n]
            let tx = next.x - prev.x, ty = next.y - prev.y
            let len = max(hypot(tx, ty), 0.0001)
            let offset = rough[i] + bow[i]
            result.append(CGPoint(x: points[i].x - ty / len * offset, y: points[i].y + tx / len * offset))
        }
        let dx = points[1].x - points[0].x, dy = points[1].y - points[0].y
        let dlen = max(hypot(dx, dy), 0.0001)
        result.append(CGPoint(x: result[0].x + dx / dlen * 1.5, y: result[0].y + dy / dlen * 1.5))
        return result
    }

    /// Random values at every `every`-th sample, smoothly interpolated and wrapped around the loop.
    private static func smoothNoise(count: Int, every: Int, amplitude: CGFloat,
                                    random: inout SeededRandom) -> [CGFloat] {
        let controls = max(count / every, 1)
        let values = (0..<controls).map { _ in CGFloat(random.signed()) * amplitude }
        return (0..<count).map { i in
            let position = CGFloat(i) / CGFloat(count) * CGFloat(controls)
            let k = Int(position) % controls
            let t = position - CGFloat(Int(position))
            let s = t * t * (3 - 2 * t)
            return values[k] * (1 - s) + values[(k + 1) % controls] * s
        }
    }
}
