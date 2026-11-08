import CoreGraphics
import DesignSystem

/// Boards A1, A1m, A1n, E1, E3, E3b (docs/superpowers/layout, v5 "Home panel lines") through
/// "Sizing formulas": the home screen's parts as screen rects, lines and baselines. The panel lines
/// are fixed: a block with less content leaves space below it, nothing moves up. The clock area is left-anchored (disc
/// centre (448, 528), R 372); the panel stretches from 928 s to W − 64 s with every part's left
/// on 928 and the way picture's right on 1312.
public struct HomeLayout: Equatable, Sendable {
    public let sizing: Sizing

    public init(sizing: Sizing) {
        self.sizing = sizing
    }

    private var s: CGFloat { sizing.s }

    // Clock and sky switch
    public var clockCentre: CGPoint { CGPoint(x: sizing.left(448), y: sizing.y(528)) }
    public var skySwitch: CGRect { sizing.left(40, 36, 160, 96) }

    // Panel (928 s … W − 64 s)
    public var panelLeft: CGFloat { sizing.left(928) }
    public var panelRight: CGFloat { sizing.right(1312) }
    public var weekdayBaseline: CGFloat { sizing.y(132) }

    /// A kid's face badge (48) and name (head 36, left 992) at the top of their block.
    public func kidBadge(top: CGFloat) -> CGRect { CGRect(x: panelLeft, y: sizing.y(top), width: 48 * s, height: 48 * s) }
    public var kidNameLeft: CGFloat { sizing.left(992) }
    public func kidNameBaseline(top: CGFloat) -> CGFloat { sizing.y(top + 24) }

    // Kid A block (badge at 163)
    public let kidATop: CGFloat = 163
    /// The way picture (80) ends on the panel's right edge.
    public var way: CGRect { CGRect(x: panelRight - 80 * s, y: sizing.y(227), width: 80 * s, height: 80 * s) }
    public var timeBaseline: CGFloat { sizing.y(402) }
    public var statusBaseline: CGFloat { sizing.y(446) }

    /// Where a Next row sits: the picture (104) on 928, the title and "at …" at 1056 (gap 24),
    /// baselines 48 and 86 below the picture's top (board E3).
    public struct RowPlace: Equatable, Sendable {
        public let picture: CGRect
        public let textLeft: CGFloat
        public let titleBaseline: CGFloat
        public let atBaseline: CGFloat
    }

    private func row(top: CGFloat) -> RowPlace {
        RowPlace(picture: CGRect(x: panelLeft, y: sizing.y(top), width: 104 * s, height: 104 * s),
                 textLeft: sizing.left(1056), titleBaseline: sizing.y(top + 48), atBaseline: sizing.y(top + 86))
    }

    /// Kid A's first line ("Leave in", "Bed in", "Next") on 301 on every home board (layout v5).
    public var firstLineBaseline: CGFloat { sizing.y(301) }

    /// E3 / E3b: "Next" (caption) on 301, then the row at 315.
    public var nextRow: RowPlace { row(top: 315) }

    /// A1n: "Bed in" on 301 and the time left on 402, then the row at 436.
    public var timeLeftRow: RowPlace { row(top: 436) }

    /// E1 (one kid, leaving): "Next" on 584 (Kid B's name line), the row at 598.
    public var leaveNextCaptionBaseline: CGFloat { sizing.y(584) }
    public var leaveNextRow: RowPlace { row(top: 598) }

    /// Kid B's badge top: 560 on every home board (name on 584; layout v5), whatever Kid A shows.
    public let kidBTop: CGFloat = 560

    /// Now (160) and next (104) circles, bottoms aligned on 792, 72 below Kid B's badge top.
    public func nowNext(kidBTop: CGFloat) -> CGPoint { CGPoint(x: panelLeft, y: sizing.y(kidBTop + 72)) }

    /// "Missions →", the panel's width, bottom 968.
    public var button: CGRect { CGRect(x: panelLeft, y: sizing.y(872), width: panelRight - panelLeft, height: 96 * s) }
}
