import CoreGraphics
import DesignSystem

/// Boards A1, A1m, A1b, A1n, E1, E3, E3b (docs/superpowers/layout, v68 "Home panel lines"), every board
/// value × s (spec "Sizing: one scale, no floors"): the home screen's parts as screen rects, lines
/// and baselines. Kid A's lines are fixed; Kid B's block moves as one unit 40 below Kid A's last part
/// (`kidBTop(after:)`). The clock disc's centre is (448, 528), R 372; the panel runs 928–1336
/// (layout v29) with every part's left on 928.
public struct HomeLayout: Equatable, Sendable {
    public let sizing: Sizing

    public init(sizing: Sizing) {
        self.sizing = sizing
    }

    private var s: CGFloat { sizing.s }

    // Clock and sky switch
    public var clockCentre: CGPoint { CGPoint(x: sizing.x(448), y: sizing.y(528)) }
    /// 160 × 96, × s.
    public var skySwitch: CGRect {
        let height = sizing.kidCornerControl
        return CGRect(x: sizing.x(40), y: sizing.y(36), width: height * 160 / 96, height: height)
    }
    /// Board G0: the pencil `RoundButton`, as tall as the sky switch (96; user, 2026-11-15: the 80
    /// circle looked tight beside it) and on its centre line (y 36–132), 40 from the glass (1240–1336).
    public var pencil: CGRect {
        let side = sizing.kidCornerControl
        return CGRect(x: sizing.x(1336) - side, y: sizing.y(36), width: side, height: side)
    }

    // Panel (928–1336, layout v29: the right margin matches the sky switch's 40)
    public var panelLeft: CGFloat { sizing.x(928) }
    public var panelRight: CGFloat { sizing.x(1336) }
    public var weekdayBaseline: CGFloat { sizing.y(132) }

    /// A kid's face badge (48) and name (head 36, left 992) at the top of their block.
    public func kidBadge(top: CGFloat) -> CGRect { CGRect(x: panelLeft, y: sizing.y(top), width: 48 * s, height: 48 * s) }
    public var kidNameLeft: CGFloat { sizing.x(992) }
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
    public var kidATextLeft: CGFloat { sizing.x(1040) }
    public var kidALabelBaseline: CGFloat { sizing.y(265) }
    public var kidATimeBaseline: CGFloat { sizing.y(337) }
    public var kidAStatusBaseline: CGFloat { sizing.y(374) }

    /// Where a Next row sits: the picture (104) on 928, then at 1048 (gap 16) "Next" (caption), the
    /// title and the time line, 21, 62 and 100 below the picture's top (the `NextRow` part's lines).
    public struct RowPlace: Equatable, Sendable {
        public let picture: CGRect
        public let textLeft: CGFloat
        /// "Next" beside the picture; the small row under the time left has none.
        public let labelBaseline: CGFloat?
        public let titleBaseline: CGFloat
        public let atBaseline: CGFloat
    }

    /// The lines come from the `NextRow` part itself, so the layout tests check what it draws.
    private func row(top: CGFloat) -> RowPlace {
        let side = NextRow.pictureSide * s
        return RowPlace(picture: CGRect(x: panelLeft, y: sizing.y(top), width: side, height: side),
                        textLeft: sizing.x(928 + NextRow.textLeft), labelBaseline: sizing.y(top + NextRow.captionBaseline),
                        titleBaseline: sizing.y(top + NextRow.titleBaseline), atBaseline: sizing.y(top + NextRow.lineBaseline))
    }

    /// E3 / E3b: the Next row at 238.
    public var nextRow: RowPlace { row(top: 238) }

    /// A1n: the Tomorrow row, 24 below the time left at 367: a 56 picture on an 80 plate, text at
    /// 1024 (gap 16) on 404 and 435.
    public var timeLeftRow: RowPlace {
        RowPlace(picture: CGRect(x: panelLeft, y: sizing.y(367), width: 80 * s, height: 80 * s),
                 textLeft: sizing.x(1024), labelBaseline: nil, titleBaseline: sizing.y(404),
                 atBaseline: sizing.y(435))
    }

    /// E1 (one kid, leaving): the second block's Next row at 435, under "On time".
    public var leaveNextRow: RowPlace { row(top: 435) }

    /// The last part of Kid A's block, whose bottom Kid B's block hangs from (board units).
    /// ux-states: home, Kid A block end
    public enum KidAEnd: Equatable, Sendable {
        /// Only the name (nothing next today): the name box ends at 214.
        case name
        /// E3 / E3b: the Next row's time line ends at 348.
        case nextRow
        /// A1m: the time-left box ends at 360.
        case timeLeft
        /// A1: "On time" ends at 396.
        case status
        /// A1n: the Tomorrow row under the time left ends at 446.
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

    /// Layout v8 "kidBRule": Kid B's name box starts 40 below Kid A's last part, its baseline never
    /// lower than 584; returns the badge top (board units).
    public func kidBTop(after end: KidAEnd) -> CGFloat {
        let nameBaseline = min(end.bottom + 40 + 28, 584)
        return nameBaseline - 24
    }

    /// Layout v68: Kid B's Now row, its picture's top 50 below the name baseline (the badge top + 24).
    public func kidBNowRow(kidBTop: CGFloat) -> RowPlace { row(top: kidBTop + 24 + 50) }
    /// Kid B's Next row, 126 below the Now row.
    public func kidBNextRow(kidBTop: CGFloat) -> RowPlace { row(top: kidBTop + 24 + 50 + 126) }

    /// "Missions →", the panel's width, bottom 968.
    public var button: CGRect { CGRect(x: panelLeft, y: sizing.y(872), width: panelRight - panelLeft, height: 96 * s) }
}
