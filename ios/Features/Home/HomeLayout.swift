import CoreGraphics
import DesignSystem

/// Boards A1, A1m, A1b, A1n, A1z, A1k, E1, E3, E3b, E3h, G0 (docs/superpowers/layout, v75), every board
/// value × s (spec "Sizing: one scale, no floors"): the home screen's parts as screen rects. The clock
/// disc's centre is (448, 528), R 372. The right panel (928–1336) stacks from the bottom up (spec A1
/// "Right panel numbers"): the kid chips 872–968, the next card 24 above them (bottom 848), then the
/// later rows from 24 above the card, 16 apart, never above the top buttons (132).
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
    /// Board 0g: the night wipe spreads from the sky switch's centre while the switch animates.
    public func skyWipe(_ isAnimating: Bool) -> CGPoint? {
        isAnimating ? CGPoint(x: skySwitch.midX, y: skySwitch.midY) : nil
    }

    /// Board G0: the pencil `RoundButton`, as tall as the sky switch (96; user, 2026-11-15: the 80
    /// circle looked tight beside it) and on its centre line (y 36–132), 40 from the glass (1240–1336).
    public var pencil: CGRect {
        let side = sizing.kidCornerControl
        return CGRect(x: sizing.x(1336) - side, y: sizing.y(36), width: side, height: side)
    }

    /// Board G0 (layout v81): the calendar `RoundButton` 96, 16 left of the pencil (1128–1224, y 36–132).
    public var calendarButton: CGRect {
        let side = sizing.kidCornerControl
        return CGRect(x: pencil.minX - 16 * s - side, y: sizing.y(36), width: side, height: side)
    }

    // Panel (928–1336, layout v29: the right margin matches the sky switch's 40)
    public var panelLeft: CGFloat { sizing.x(928) }
    public var panelRight: CGFloat { sizing.x(1336) }

    /// Board units: the chips' row, the card's bottom and the rows' gap and ceiling.
    public static let chipTop: CGFloat = 872
    public static let chipGap: CGFloat = 12
    public static let cardBottom: CGFloat = 848
    public static let rowGap: CGFloat = 16
    /// The nearest later row ends 24 above the card (boards A1, A1k: 712 over 736).
    public static let cardGap: CGFloat = 24
    /// The rows never climb past the top buttons' bottom (132) and a gap.
    public static let rowCeiling: CGFloat = 132 + rowGap

    /// Kid chip `index` of `count`: equal widths across the panel, gap 12, y 872–968.
    public func chip(_ index: Int, of count: Int) -> CGRect {
        let total: CGFloat = 1336 - 928, width = (total - Self.chipGap * CGFloat(max(count - 1, 0))) / CGFloat(max(count, 1))
        return CGRect(x: sizing.x(928 + CGFloat(index) * (width + Self.chipGap)), y: sizing.y(Self.chipTop),
                      width: width * s, height: KidChip.height * s)
    }

    /// The next card: the part's frame on the panel (its hatch bleeds 12 to the left by itself).
    public var card: CGRect {
        let height = NextThingRow.height(size: .card, isMission: false)
        return CGRect(x: panelLeft, y: sizing.y(Self.cardBottom - height), width: NextThingRow.width * s, height: height * s)
    }

    /// Board tops of the later rows, nearest first, climbing from 16 above the card.
    static func rowTops(_ isMission: [Bool]) -> [CGFloat] {
        var bottom = Self.cardBottom - NextThingRow.height(size: .card, isMission: false) - Self.cardGap
        return isMission.map { mission in
            let top = bottom - NextThingRow.height(size: .row, isMission: mission)
            bottom = top - Self.rowGap
            return top
        }
    }

    /// How many of the later rows (nearest first) fit under the ceiling (spec A1 "Items": the
    /// farthest drop off the top). Board units, so it is the same on every iPad.
    public static func rowsThatFit(_ isMission: [Bool]) -> Int {
        rowTops(isMission).prefix { $0 >= Self.rowCeiling }.count
    }

    /// Later row `index` (nearest first) on screen.
    public func row(_ index: Int, of isMission: [Bool]) -> CGRect {
        let top = Self.rowTops(isMission)[index]
        let height = NextThingRow.height(size: .row, isMission: isMission[index])
        return CGRect(x: panelLeft, y: sizing.y(top), width: NextThingRow.width * s, height: height * s)
    }
}
