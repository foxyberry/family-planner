import CoreGraphics
import DesignSystem

/// Boards A1, A1m, A1n, E1, E3, E3b (docs/superpowers/layout, v17 "Home panel lines") through
/// "Sizing formulas": the home screen's parts as screen rects, lines and baselines. Kid A's lines are
/// fixed; Kid B's block moves as one unit 40 below Kid A's last part (`kidBTop(after:)`). The clock
/// area is left-anchored (disc
/// centre (448, 528), R 372); the panel stretches from 928 s to W − 40 s (layout v29) with every
/// part's left on 928.
public struct HomeLayout: Equatable, Sendable {
    public let sizing: Sizing

    public init(sizing: Sizing) {
        self.sizing = sizing
    }

    private var s: CGFloat { sizing.s }

    // Clock and sky switch
    public var clockCentre: CGPoint { CGPoint(x: sizing.left(448), y: sizing.y(528)) }
    public var skySwitch: CGRect { sizing.left(40, 36, 160, 96) }
    /// Board G0: the pencil `RoundButton` 80 at (1260, 44), 40 from the glass like the sky switch.
    public var pencil: CGRect { CGRect(x: sizing.right(1260), y: sizing.y(44), width: 80 * s, height: 80 * s) }

    // Panel (928 s … W − 40 s, layout v29: the right margin matches the sky switch's 40)
    public var panelLeft: CGFloat { sizing.left(928) }
    public var panelRight: CGFloat { sizing.right(1336) }
    public var weekdayBaseline: CGFloat { sizing.y(132) }

    /// A kid's face badge (48) and name (head 36, left 992) at the top of their block.
    public func kidBadge(top: CGFloat) -> CGRect { CGRect(x: panelLeft, y: sizing.y(top), width: 48 * s, height: 48 * s) }
    public var kidNameLeft: CGFloat { sizing.left(992) }
    public func kidNameBaseline(top: CGFloat) -> CGFloat { sizing.y(top + 24) }
    /// The name's box beside the badge, as tall as the badge, so the name sits on its middle
    /// (user, 2026-11-09: the baseline on the badge's middle put the name too high).
    public func kidName(top: CGFloat) -> CGRect {
        CGRect(x: kidNameLeft, y: sizing.y(top), width: panelRight - kidNameLeft, height: 48 * s)
    }

    // Kid A block, look ① (layout v17): the badge at 163, then one row 24 below the name with the
    // picture on 928 and the words stacked to its right.
    public let kidATop: CGFloat = 163

    /// Leave / Bed shape: the way picture (or the moon on a plate) 96 at (928, 241); the label on
    /// 265 and the time left (72) on 337 at 1040; "On time" on 374.
    public var kidAPicture: CGRect { CGRect(x: panelLeft, y: sizing.y(241), width: 96 * s, height: 96 * s) }
    public var kidATextLeft: CGFloat { sizing.left(1040) }
    public var kidALabelBaseline: CGFloat { sizing.y(265) }
    public var kidATimeBaseline: CGFloat { sizing.y(337) }
    public var kidAStatusBaseline: CGFloat { sizing.y(374) }

    /// Where a Next row sits: the picture (104) on 928, then at 1048 (gap 16) "Next" (caption), the
    /// title and "at …", 21, 62 and 100 below the picture's top.
    public struct RowPlace: Equatable, Sendable {
        public let picture: CGRect
        public let textLeft: CGFloat
        /// "Next" beside the picture; the small row under the time left has none.
        public let labelBaseline: CGFloat?
        public let titleBaseline: CGFloat
        public let atBaseline: CGFloat
    }

    private func row(top: CGFloat) -> RowPlace {
        RowPlace(picture: CGRect(x: panelLeft, y: sizing.y(top), width: 104 * s, height: 104 * s),
                 textLeft: sizing.left(1048), labelBaseline: sizing.y(top + 21),
                 titleBaseline: sizing.y(top + 62), atBaseline: sizing.y(top + 100))
    }

    /// E3 / E3b: the Next row at 238.
    public var nextRow: RowPlace { row(top: 238) }

    /// A1n: the 80 row 24 below the time left (Tomorrow, or Next by day) at 367: a 56 picture on an
    /// 80 plate, text at 1024 (gap 16) on 404 and 435.
    public var timeLeftRow: RowPlace {
        RowPlace(picture: CGRect(x: panelLeft, y: sizing.y(367), width: 80 * s, height: 80 * s),
                 textLeft: sizing.left(1024), labelBaseline: nil, titleBaseline: sizing.y(404),
                 atBaseline: sizing.y(435))
    }

    /// E1 (one kid, leaving): the second block's Next row at 435, under "On time".
    public var leaveNextRow: RowPlace { row(top: 435) }

    /// The last part of Kid A's block, whose bottom Kid B's block hangs from (board units).
    public enum KidAEnd: Equatable, Sendable {
        /// Only the name (nothing next today): the name box ends at 214.
        case name
        /// E3 / E3b: the Next row's "at …" ends at 348.
        case nextRow
        /// A1m: the time-left box ends at 360.
        case timeLeft
        /// A1: "On time" ends at 396.
        case status
        /// A1n: the 80 row under the time left ends at 446.
        case timeLeftRow

        var bottom: CGFloat {
            switch self {
            case .name: 214
            case .nextRow: 348
            case .timeLeft: 360
            case .status: 396
            case .timeLeftRow: 446
            }
        }
    }

    /// Layout v8 "kidBRule": Kid B's name box starts 40 (a space token, 28 at the floor) below Kid
    /// A's last part, its baseline never lower than 584; returns the badge top (board units).
    public func kidBTop(after end: KidAEnd) -> CGFloat {
        let nameBaseline = min(end.bottom + sizing.space(40) / s + 28, 584)
        return nameBaseline - 24
    }

    /// Now (160) and next (104) circles, bottoms aligned, 48 below Kid B's name baseline.
    public func nowNext(kidBTop: CGFloat) -> CGPoint { CGPoint(x: panelLeft, y: sizing.y(kidBTop + 72)) }

    /// "Missions →", the panel's width, bottom 968.
    public var button: CGRect { CGRect(x: panelLeft, y: sizing.y(872), width: panelRight - panelLeft, height: 96 * s) }
}
