import CoreGraphics

/// Spec "A2 strip, when labels collide" (user, 2026-11-19: one row above, one under, no merged
/// listing): where each tag goes, in arrival order. Row 0 ends 8 above the bus top, row 1 starts 8
/// under the bus box; a tag takes row 1 when row 0 would overlap an earlier tag or the my-bus
/// bubble, and is left out when neither row is free (its bus stays, faded). Works in screen points, so the real tag widths count on every iPad.
public enum LiveTagLayout {
    public struct Tag: Equatable, Sendable {
        public var centreX: CGFloat
        public var width: CGFloat

        public init(centreX: CGFloat, width: CGFloat) {
            self.centreX = centreX
            self.width = width
        }
    }

    public enum Slot: Equatable, Sendable {
        /// Shown in `row` (0 above the bus, 1 under it) with its frame.
        case shown(row: Int, frame: CGRect)
        /// No free row: the bus has no tag.
        case hidden
    }

    /// The strip's lines on screen: `kx` and `k` its two scales (board units to points), `bubble`
    /// the my-bus bubble's frame (nil when no bus can be caught).
    public static func place(_ tags: [Tag], kx: CGFloat, k: CGFloat, bubble: CGRect?) -> [Slot] {
        let height = LiveBusTag.height * k
        let rowTops = [busTop * k - 8 * k - height, busBottom * k + 8 * k]
        var slots: [Slot] = []
        var shown: [CGRect] = []
        for tag in tags {
            let x = min(max(tag.centreX - tag.width / 2, 8 * kx), 1240 * kx - tag.width)
            let free = rowTops.indices.lazy.map { row in (row, CGRect(x: x, y: rowTops[row], width: tag.width, height: height)) }
                .first { _, frame in
                    !shown.contains { $0.insetBy(dx: -2 * k, dy: 0).intersects(frame) }
                        && !(bubble?.intersects(frame) ?? false)
                }
            if let (row, frame) = free {
                slots.append(.shown(row: row, frame: frame))
                shown.append(frame)
            } else {
                slots.append(.hidden)
            }
        }
        return slots
    }

    /// The bus box on the board: top 140, bottom 260.
    static let busTop: CGFloat = 140
    static let busBottom: CGFloat = 260
}
