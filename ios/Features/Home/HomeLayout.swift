import CoreGraphics
import DesignSystem

/// Boards A1, A1m, A1b, A1n, E1, E3, E3b, E3h (docs/superpowers/layout, v71 "Home panel lines"), every
/// board value × s (spec "Sizing: one scale, no floors"): the home screen's parts as screen rects,
/// lines and baselines. Kid A's lines are fixed; Kid B's block moves as one unit 40 below Kid A's last
/// part (`kidBTop(after:)`). The clock disc's centre is (448, 528), R 372; the panel runs 928–1336
/// (layout v29) with every part's left on 928, from y 132 (layout v71: 36 lower, so the weekday
/// passes under the calendar and pencil buttons).
public struct HomeLayout: Equatable, Sendable {
    public let sizing: Sizing
    /// Board E3h: a holiday's (or break's) name line under the weekday, which pushes the rest of the
    /// panel down by its 32.
    public let hasDayNote: Bool

    public init(sizing: Sizing, dayNote: Bool = false) {
        self.sizing = sizing
        hasDayNote = dayNote
    }

    private var s: CGFloat { sizing.s }
    /// Kid A's block below the weekday moves down by the name line (board units).
    private var note: CGFloat { hasDayNote ? Self.dayNoteHeight : 0 }
    /// Spec "Hub text": the name's baseline 32 below the weekday's; the panel below moves by as much.
    public static let dayNoteHeight: CGFloat = 32

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

    /// Board G0 (layout v71): the calendar `RoundButton` 96, 16 left of the pencil (1128–1224, y 36–132).
    public var calendarButton: CGRect {
        let side = sizing.kidCornerControl
        return CGRect(x: pencil.minX - 16 * s - side, y: sizing.y(36), width: side, height: side)
    }

    // Panel (928–1336, layout v29: the right margin matches the sky switch's 40)
    public var panelLeft: CGFloat { sizing.x(928) }
    public var panelRight: CGFloat { sizing.x(1336) }
    public var weekdayBaseline: CGFloat { sizing.y(168) }
    /// Board E3h: the holiday's name (caption 24) 32 below the weekday.
    public var dayNoteBaseline: CGFloat { sizing.y(168 + Self.dayNoteHeight) }

    /// A kid's face badge (48) and name (head 36, left 992) at the top of their block.
    public func kidBadge(top: CGFloat) -> CGRect { CGRect(x: panelLeft, y: sizing.y(top), width: 48 * s, height: 48 * s) }
    public var kidNameLeft: CGFloat { sizing.x(992) }
    public func kidNameBaseline(top: CGFloat) -> CGFloat { sizing.y(top + 24) }
    /// The name's box beside the badge, as tall as the badge, so the name sits on its middle
    /// (user, 2026-11-09: the baseline on the badge's middle put the name too high).
    public func kidName(top: CGFloat) -> CGRect {
        CGRect(x: kidNameLeft, y: sizing.y(top), width: panelRight - kidNameLeft, height: 48 * s)
    }

    // Kid A block, look ① (layout v17, v71 +36): the badge at 199, then one row 24 below the name
    // with the picture on 928 and the words stacked to its right.
    public var kidATop: CGFloat { 199 + note }

    /// Leave / Bed shape: the way picture (or the moon on a plate) 96 at (928, 277); the label on
    /// 301 and the time left (72) on 373 at 1040; "On time" on 410.
    public var kidAPicture: CGRect { CGRect(x: panelLeft, y: sizing.y(277 + note), width: 96 * s, height: 96 * s) }
    public var kidATextLeft: CGFloat { sizing.x(1040) }
    public var kidALabelBaseline: CGFloat { sizing.y(301 + note) }
    public var kidATimeBaseline: CGFloat { sizing.y(373 + note) }
    public var kidAStatusBaseline: CGFloat { sizing.y(410 + note) }

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

    /// E3 / E3b: the Next row at 274 (E3h: 306, under the name line).
    public var nextRow: RowPlace { row(top: 274 + note) }

    /// A1n: the Tomorrow row, 24 below the time left at 403: a 56 picture on an 80 plate, text at
    /// 1024 (gap 16) on 440 and 471.
    public var timeLeftRow: RowPlace {
        RowPlace(picture: CGRect(x: panelLeft, y: sizing.y(403 + note), width: 80 * s, height: 80 * s),
                 textLeft: sizing.x(1024), labelBaseline: nil, titleBaseline: sizing.y(440 + note),
                 atBaseline: sizing.y(471 + note))
    }

    /// E1 (one kid, leaving): the second block's Next row at 471, under "On time".
    public var leaveNextRow: RowPlace { row(top: 471 + note) }

    /// The last part of Kid A's block, whose bottom Kid B's block hangs from (board units).
    /// ux-states: home, Kid A block end
    public enum KidAEnd: Equatable, Sendable, CaseIterable {
        /// Only the name (nothing next today): the name box ends at 250.
        case name
        /// E3 / E3b: the Next row's time line ends at 384.
        case nextRow
        /// A1m: the time-left box ends at 396.
        case timeLeft
        /// A1: "On time" ends at 432.
        case status
        /// A1n: the Tomorrow row under the time left ends at 482.
        case timeLeftRow

        /// Without the name line (layout v71).
        var bottom: CGFloat {
            switch self {
            case .name: 250
            case .nextRow: 384
            case .timeLeft: 396
            case .status: 432
            case .timeLeftRow: 482
            }
        }
    }

    /// Layout v8 "kidBRule" (v71 values): Kid B's name box starts 40 below Kid A's last part, its
    /// baseline never lower than 620; returns the badge top (board units).
    public func kidBTop(after end: KidAEnd) -> CGFloat {
        let nameBaseline = min(end.bottom + note + 40 + 28, 620)
        return nameBaseline - 24
    }

    /// Layout v68: Kid B's Now row, its picture's top 50 below the name baseline (the badge top + 24).
    public func kidBNowRow(kidBTop: CGFloat) -> RowPlace { row(top: kidBTop + 24 + 50) }
    /// Kid B's Next row, 126 below the Now row.
    public func kidBNextRow(kidBTop: CGFloat) -> RowPlace { row(top: kidBTop + 24 + 50 + 126) }

    /// "Missions →", the panel's width, bottom 968.
    public var button: CGRect { CGRect(x: panelLeft, y: sizing.y(872), width: panelRight - panelLeft, height: 96 * s) }
}
