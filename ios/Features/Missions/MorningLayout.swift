import CoreGraphics
import DesignSystem

/// Spec "A2 redlines" (boards A2, A2t, A2t-w, A3), every board value × s (spec "Sizing: one scale,
/// no floors"): every part of the morning screen as a screen rect, line or baseline. The view only
/// places parts here; the layout test checks the lines at s = 1 and on a small window.
///
/// Shared lines: x 64 (back button, strip, kid list), x 448 (missions column: name line, first
/// circle, slide), x 1312 (header right, strip right, last circle, slide right), x 172
/// (text inside the kid rows); baselines 107 (header), 584 (row 1 name = missions name line),
/// 757 (circle captions). The missions column runs 448–1312.
public struct MorningLayout: Equatable, Sendable {
    public let sizing: Sizing

    public init(sizing: Sizing) {
        self.sizing = sizing
    }

    private var s: CGFloat { sizing.s }

    // MARK: Header (48–128)

    public var back: CGRect { sizing.rect(64, 48, 80, 80) }
    public var titleLeft: CGFloat { sizing.x(168) }
    public var headerBaseline: CGFloat { sizing.y(107) }
    /// The right group ("Leave in" · minutes · status) ends here.
    public var headerRight: CGFloat { sizing.x(1312) }

    // MARK: Strip (176–516)

    /// The strip region; the strip keeps its 1248 : 340 shape, centred in it.
    public var strip: CGRect { sizing.rect(64, 176, 1312 - 64, 340) }

    // MARK: Kid list

    public func kidRow(_ index: Int) -> CGRect { sizing.rect(64, 536 + 108 * CGFloat(index), 340, 100) }
    /// The band is 14 wider than the row: its notch tip is at x 418.
    public func kidBand(_ index: Int) -> CGRect { sizing.rect(64, 536 + 108 * CGFloat(index), 354, 100) }
    public func kidRing(_ index: Int) -> CGRect { sizing.rect(80, 548 + 108 * CGFloat(index), 76, 76) }
    public func kidFace(_ index: Int) -> CGRect { sizing.rect(85, 553 + 108 * CGFloat(index), 66, 66) }
    public var kidTextLeft: CGFloat { sizing.x(172) }
    public func kidNameBaseline(_ index: Int) -> CGFloat { sizing.y(584 + 108 * CGFloat(index)) }
    public func kidCaptionBaseline(_ index: Int) -> CGFloat { sizing.y(614 + 108 * CGFloat(index)) }

    // MARK: Missions column (448–1312)

    public var columnLeft: CGFloat { sizing.x(448) }
    public var columnRight: CGFloat { sizing.x(1312) }
    public var columnWidth: CGFloat { columnRight - columnLeft }
    public var nameBaseline: CGFloat { sizing.y(584) }

    /// 112 × s.
    public var circle: CGFloat { 112 * s }
    /// Six tracks from the first circle at 448 to the last circle ending at 1312.
    public var pitch: CGFloat { (columnWidth - circle) / 5 }
    public func circleRect(_ index: Int) -> CGRect {
        CGRect(x: columnLeft + pitch * CGFloat(index), y: sizing.y(612), width: circle, height: circle)
    }

    // MARK: Done view (board A3r): the medal 200 on the circle row, the words 40 to its right

    public var doneMedal: CGRect { CGRect(x: columnLeft, y: sizing.y(612), width: 200 * s, height: 200 * s) }
    public var doneTextLeft: CGFloat { columnLeft + 240 * s }
    public var doneTitleBaseline: CGFloat { sizing.y(728) }
    public var doneSubtitleBaseline: CGFloat { sizing.y(776) }

    // MARK: Bottom control (bottom 968)

    public var slide: CGRect { CGRect(x: columnLeft, y: sizing.y(872), width: columnWidth, height: 96 * s) }
}
