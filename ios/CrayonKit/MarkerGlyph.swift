import CoreGraphics

/// Small marker-drawn glyphs (spec "CrayonKit UI parts": board 0b). Each is a few strokes in a
/// 48 box, drawn as one slightly wobbly marker pass with a fixed seed, so it looks the same every
/// time and like the rest of the crayon UI. Playpen Sans has no arrows, so these replace text glyphs.
public enum MarkerGlyph: String, CaseIterable, Sendable {
    /// `handle` is the drag handle ≡ of reorderable rows (C5); `lock` the grown-up lock (S4, over a
    /// yellow crayon body: `LockMark`). New cases go last: the order seeds them.
    case chevronLeft, chevronRight, arrowRight, plus, minus, handle, lock, close, undo, redo, chevronDown

    /// The strokes in the 48 box (spec paths).
    public var strokes: [[CGPoint]] {
        switch self {
        case .chevronLeft: [[p(30, 10), p(16, 24), p(30, 38)]]
        case .chevronRight: [[p(18, 10), p(32, 24), p(18, 38)]]
        // G1's day button: the picker opens below.
        case .chevronDown: [[p(10, 18), p(24, 32), p(38, 18)]]
        case .arrowRight: [[p(10, 24), p(38, 24)], [p(26, 12), p(38, 24), p(26, 36)]]
        case .plus: [[p(24, 10), p(24, 38)], [p(10, 24), p(38, 24)]]
        case .minus: [[p(10, 24), p(38, 24)]]
        // S1 "Remove a kid" (layout v13): two strokes corner to corner.
        case .close: [[p(14, 14), p(34, 34)], [p(34, 14), p(14, 34)]]
        case .handle: [[p(12, 15), p(36, 15)], [p(12, 24), p(36, 24)], [p(12, 33), p(36, 33)]]
        // G1 Undo / Redo (spec "Grown-up mode"): a hook arrow, back to the left or on to the right.
        case .undo: hook
        case .redo: hook.map { stroke in stroke.map { p(48 - $0.x, $0.y) } }
        case .lock:
            [[p(15, 22), p(15, 15), p(18, 10), p(24, 8), p(30, 10), p(33, 15), p(33, 22)],
             [p(10, 22), p(38, 22), p(38, 42), p(10, 42), p(10, 22)], [p(24, 29), p(24, 35)]]
        }
    }

    private var hook: [[CGPoint]] {
        [[p(10, 16), p(28, 16), p(35, 19), p(40, 25), p(40, 31), p(35, 37), p(28, 40), p(18, 40)],
         [p(17, 9), p(10, 16), p(17, 23)]]
    }

    /// The strokes scaled to `size`, each segment split every 4 pt and nudged by up to 0.6 pt
    /// (seeded), so straight runs drift a little like a marker.
    public func path(size: CGFloat, seed: UInt32) -> [[CGPoint]] {
        var random = SeededRandom(seed: seed)
        let scale = size / 48
        return strokes.map { stroke in
            var points: [CGPoint] = []
            for (a, b) in zip(stroke, stroke.dropFirst()) {
                let length = hypot(b.x - a.x, b.y - a.y) * scale
                let steps = max(1, Int(length / 4))
                for step in 0..<steps {
                    let t = CGFloat(step) / CGFloat(steps)
                    let wobble = step == 0 ? 0 : CGFloat(random.next() * 1.2 - 0.6)
                    points.append(CGPoint(x: (a.x + (b.x - a.x) * t) * scale + wobble,
                                          y: (a.y + (b.y - a.y) * t) * scale + wobble))
                }
            }
            if let last = stroke.last { points.append(CGPoint(x: last.x * scale, y: last.y * scale)) }
            return points
        }
    }

    /// The lock's body in the 48 box, for the crayon fill under it.
    public static let lockBody = CGRect(x: 10, y: 22, width: 28, height: 20)

    private func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }
}
