import CoreGraphics
import DesignSystem

/// Boards A1, A1m, A1n, E1, E3 (docs/superpowers/layout) through "Sizing formulas": the home
/// screen's parts as screen rects, lines and baselines. The clock area is left-anchored (disc
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
    public var labelBaseline: CGFloat { sizing.y(301) }
    public var timeBaseline: CGFloat { sizing.y(402) }
    public var statusBaseline: CGFloat { sizing.y(446) }

    /// Kid B's block starts lower when Kid A has a status line (A1: 528, A1m: 475).
    public func kidBTop(hasStatus: Bool) -> CGFloat { hasStatus ? 529 : 475 }
    /// Now (160) and next (104) circles, bottoms aligned, 75 below Kid B's badge.
    public func nowNext(kidBTop: CGFloat) -> CGPoint { CGPoint(x: panelLeft, y: sizing.y(kidBTop + 72)) }

    // E1 (one kid): Next row under Kid A
    public var nextLabelBaseline: CGFloat { sizing.y(554) }
    public var nextPicture: CGRect { CGRect(x: panelLeft, y: sizing.y(568), width: 104 * s, height: 104 * s) }
    public var nextTextLeft: CGFloat { sizing.left(1056) }
    public var nextTitleBaseline: CGFloat { sizing.y(616) }
    public var nextTimeBaseline: CGFloat { sizing.y(654) }

    /// "Missions →", the panel's width, bottom 968.
    public var button: CGRect { CGRect(x: panelLeft, y: sizing.y(872), width: panelRight - panelLeft, height: 96 * s) }
}
