import CoreGraphics
import DesignSystem

/// Boards S1–S4 (layout v10) on the grown-up lines (`GrownupLayout`) through "Sizing formulas":
/// the step note and dots end on 1312 in the header; S1 kid cards are 296 tall and 32 apart from
/// 176; S4 rows are 120 tall on a 140 pitch from 216. Inside a card, rows start on 104 (labels)
/// and 232 (controls).
public struct SetupLayout: Equatable, Sendable {
    public let grown: GrownupLayout

    public init(sizing: Sizing) {
        grown = GrownupLayout(sizing: sizing)
    }

    private var sizing: Sizing { grown.sizing }
    private var s: CGFloat { sizing.s }

    /// The four dots 28, 8 apart, ending on 1312.
    public var dots: CGRect { sizing.right(1176, 74, 136, 28) }

    /// S1: one card per kid, 64–882.
    public func kidCard(_ index: Int) -> CGRect {
        sizing.left(64, 176 + (296 + 32) * CGFloat(index), 818, 296)
    }

    public var cardHeight: CGFloat { 296 * s }
    public var cardGap: CGFloat { 32 * s }
    /// S1 card rows: Name at 48 below the card top, Colour 40 below it.
    public var cardTopInset: CGFloat { 48 * s }
    public var cardRowGap: CGFloat { 40 * s }

    /// S2 and S3: the school field 610 wide, the stop field 400.
    public var schoolFieldWidth: CGFloat { 610 * s }

    /// S4: a row 120 tall on a 140 pitch from 216.
    public func settingRow(_ index: Int) -> CGRect { sizing.left(104, 216 + 140 * CGFloat(index), 738, 120) }
    public var settingRowGap: CGFloat { 20 * s }
    public var settingTopInset: CGFloat { 40 * s }
}
