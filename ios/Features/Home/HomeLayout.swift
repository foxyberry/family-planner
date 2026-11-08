import CoreGraphics
import DesignSystem

/// Boards A1, A1m, A1n, E1, E3, E3b (docs/superpowers/layout) through "Sizing formulas": the home
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

    /// E3 / E3b: "Next" (caption) then the row, Kid B 64 below it.
    public var nextCaptionBaseline: CGFloat { sizing.y(260) }
    public var nextRow: RowPlace { row(top: 274) }

    /// A1n: the time left ("in", "Bed in") first, then the row at 401.
    public var timeLeftLabelBaseline: CGFloat { sizing.y(266) }
    public var timeLeftBaseline: CGFloat { sizing.y(368) }
    public var timeLeftRow: RowPlace { row(top: 401) }

    /// E1 (one kid, leaving): the Next row under "On time".
    public var leaveNextCaptionBaseline: CGFloat { sizing.y(554) }
    public var leaveNextRow: RowPlace { row(top: 568) }

    /// Kid B's badge top under each Kid A shape: A1 529 (with the status), A1m 475, A1n 569, E3 442.
    public enum KidAShape: Equatable, Sendable { case leave(hasStatus: Bool), timeLeft, next }
    public static func kidBTop(_ shape: KidAShape) -> CGFloat {
        switch shape {
        case .leave(let hasStatus): hasStatus ? 529 : 475
        case .timeLeft: 569
        case .next: 442
        }
    }

    /// Now (160) and next (104) circles, bottoms aligned, 72 below Kid B's badge top.
    public func nowNext(kidBTop: CGFloat) -> CGPoint { CGPoint(x: panelLeft, y: sizing.y(kidBTop + 72)) }

    /// "Missions →", the panel's width, bottom 968.
    public var button: CGRect { CGRect(x: panelLeft, y: sizing.y(872), width: panelRight - panelLeft, height: 96 * s) }
}
