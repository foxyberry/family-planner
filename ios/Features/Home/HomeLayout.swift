import CoreGraphics
import DesignSystem

/// Boards A1, A1m, A1b, A1n, A1z, E1, E3, E3b, E3h, G0 (docs/superpowers/layout, v73 "Home panel
/// lines"), every board value × s (spec "Sizing: one scale, no floors"): the home screen's parts as screen rects,
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

    /// Board G0 (layout v74): the calendar `RoundButton` 96, 16 left of the pencil (1128–1224, y 36–132).
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

    // Kid A block (layout v73, look B): the badge at 199, then one row 48 below the name baseline
    // (picture top 271) with the picture 80 on 928 and the words at 1024.
    public var kidATop: CGFloat { 199 + note }
    /// Board units: the Kid A row's picture top, 48 below the name baseline (223).
    private var kidARowTop: CGFloat { 271 + note }

    /// Leave / Bed shape: the way picture (or the moon on a night plate) 80 at (928, 271); "Leave in"
    /// / "Bed in" (caption) on the picture top + 26, the time left (48 bold) on + 75, "On time"
    /// (caption bold) on + 99, at 1024.
    public var kidAPicture: CGRect {
        CGRect(x: panelLeft, y: sizing.y(kidARowTop), width: NextRow.pictureSide * s, height: NextRow.pictureSide * s)
    }
    public var kidATextLeft: CGFloat { sizing.x(928 + NextRow.textLeft) }
    public var kidALabelBaseline: CGFloat { sizing.y(kidARowTop + 26) }
    public var kidATimeBaseline: CGFloat { sizing.y(kidARowTop + 75) }
    public var kidAStatusBaseline: CGFloat { sizing.y(kidARowTop + 99) }

    /// Where a row sits: the picture (80) on 928, then at 1024 (gap 16) "{caption} · {title}" and the
    /// time line, 37 and 68 below the picture's top (the `NextRow` part's lines).
    public struct RowPlace: Equatable, Sendable {
        public let picture: CGRect
        public let textLeft: CGFloat
        public let titleBaseline: CGFloat
        public let atBaseline: CGFloat
    }

    /// The lines come from the `NextRow` part itself, so the layout tests check what it draws.
    private func row(top: CGFloat) -> RowPlace {
        let side = NextRow.pictureSide * s
        return RowPlace(picture: CGRect(x: panelLeft, y: sizing.y(top), width: side, height: side),
                        textLeft: sizing.x(928 + NextRow.textLeft), titleBaseline: sizing.y(top + NextRow.titleBaseline),
                        atBaseline: sizing.y(top + NextRow.lineBaseline))
    }

    /// E3 / E3b / A1z: the row at 271 (E3h: 303, under the name line).
    public var nextRow: RowPlace { row(top: kidARowTop) }

    /// A1n: the Tomorrow row, 104 below the Bed row (375).
    public var timeLeftRow: RowPlace { row(top: kidARowTop + 104) }

    /// E1 (one kid, leaving): the second row 37 below "On time"'s box (which ends at 388): 425.
    public var leaveNextRow: RowPlace { row(top: kidARowTop + 154) }

    /// The last part of Kid A's block, whose bottom Kid B's block hangs from (board units).
    /// ux-states: home, Kid A block end
    public enum KidAEnd: Equatable, Sendable, CaseIterable {
        /// A1z: without the row, only the name (nothing in the next 14 days); the name box ends at 250.
        case name
        /// E3 / E3b / A1z: the row's picture (or A1z's Tomorrow row's) ends at 351.
        case nextRow
        /// A1m: the time-left box ends at 362.
        case timeLeft
        /// A1: "On time" ends at 388.
        case status
        /// A1n: the Tomorrow row's picture under the Bed row ends at 455.
        case timeLeftRow

        /// Without the name line (layout v73).
        var bottom: CGFloat {
            switch self {
            case .name: 250
            case .nextRow: 351
            case .timeLeft: 362
            case .status: 388
            case .timeLeftRow: 455
            }
        }
    }

    /// Layout v8 "kidBRule" (v73 values): Kid B's name box starts 40 below Kid A's last box, its
    /// baseline 27 below that box's top and never lower than 620; returns the badge top (board units).
    public func kidBTop(after end: KidAEnd) -> CGFloat {
        let nameBaseline = min(end.bottom + note + 40 + 27, 620)
        return nameBaseline - 24
    }

    /// Layout v73: Kid B's Now row, its picture's top 48 below the name baseline (the badge top + 24).
    public func kidBNowRow(kidBTop: CGFloat) -> RowPlace { row(top: kidBTop + 24 + 48) }
    /// Kid B's Next row, 96 below the Now row.
    public func kidBNextRow(kidBTop: CGFloat) -> RowPlace { row(top: kidBTop + 24 + 48 + 96) }

    /// "Missions →", the panel's width, bottom 968.
    public var button: CGRect { CGRect(x: panelLeft, y: sizing.y(872), width: panelRight - panelLeft, height: 96 * s) }
}
