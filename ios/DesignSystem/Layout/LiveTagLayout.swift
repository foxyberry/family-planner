import CoreGraphics

/// Spec "A2 strip, when labels collide": where each tag goes, in arrival order. Row 0 ends 8 above
/// the bus top, row 1 is 50 higher, row 2 starts 8 under the bus box; a tag takes the next row when
/// it would overlap an earlier tag or the my-bus bubble, and merges with the nearest tag when no
/// row is free. Works in screen points, so the real tag widths count on every iPad.
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
        /// Shown in `row` (0 and 1 above the bus, 2 under it) with its frame.
        case shown(row: Int, frame: CGRect)
        /// Listed in the tag at this index instead.
        case merged(into: Int)
    }

    /// The strip's lines on screen: `kx` and `k` its two scales (board units to points), `bubble`
    /// the my-bus bubble's frame (nil when no bus can be caught).
    public static func place(_ tags: [Tag], kx: CGFloat, k: CGFloat, bubble: CGRect?) -> [Slot] {
        let height = LiveBusTag.height
        let rowTops = [busTop * k - 8 * k - height, busTop * k - 8 * k - height - max(50 * k, height + 4),
                       busBottom * k + 8 * k]
        var slots: [Slot] = []
        var shown: [(index: Int, frame: CGRect)] = []
        for (index, tag) in tags.enumerated() {
            let x = min(max(tag.centreX - tag.width / 2, 8 * kx), 1240 * kx - tag.width)
            let free = rowTops.indices.lazy.map { row in (row, CGRect(x: x, y: rowTops[row], width: tag.width, height: height)) }
                .first { _, frame in
                    !shown.contains { $0.frame.insetBy(dx: -2, dy: 0).intersects(frame) }
                        && !(bubble?.intersects(frame) ?? false)
                }
            if let (row, frame) = free {
                slots.append(.shown(row: row, frame: frame))
                shown.append((index, frame))
            } else if let nearest = shown.min(by: { abs($0.frame.midX - tag.centreX) < abs($1.frame.midX - tag.centreX) }) {
                slots.append(.merged(into: nearest.index))
            } else {
                slots.append(.merged(into: index))
            }
        }
        return slots
    }

    /// The bus box on the board: top 140, bottom 260.
    static let busTop: CGFloat = 140
    static let busBottom: CGFloat = 260
}
