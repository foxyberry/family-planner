import CoreGraphics
import DesignSystem

/// Boards S1–S4 (layout v10) on the grown-up lines (`GrownupLayout`) through "Sizing formulas":
/// the header ends on 1312 like every grown-up header; S1 kid cards are 296 tall and 32 apart from
/// 176; S4 rows are 120 tall on a 140 pitch from 216. Inside a card, rows start on 104 (labels)
/// and 232 (controls).
public struct SetupLayout: Equatable, Sendable {
    public let grown: GrownupLayout

    public init(sizing: Sizing) {
        grown = GrownupLayout(sizing: sizing)
    }

    private var sizing: Sizing { grown.sizing }
    private var s: CGFloat { sizing.s }

    /// S1: one card per kid, 64–882.
    public func kidCard(_ index: Int) -> CGRect {
        sizing.left(64, 176 + (304 + 20) * CGFloat(index), 818, 304)
    }

    /// Layout v18: S1 cards 304 tall, 20 apart.
    public var cardHeight: CGFloat { 304 * s }
    public var cardGap: CGFloat { 20 * s }
    /// S1 card rows: Name at 48 below the card top, Colour 40 below it.
    public var cardTopInset: CGFloat { 48 * s }
    public var cardRowGap: CGFloat { 40 * s }

    /// S2 and S3: the school field 610 wide, the stop field 400.
    public var schoolFieldWidth: CGFloat { 610 * s }

    /// S2 and S3 kid tabs (layout v17): 200 × 72 with the name, 88 × 72 face only; gap 12.
    public func kidTab(faceOnly: Bool) -> CGSize { CGSize(width: (faceOnly ? 88 : 200) * s, height: 72 * s) }
    public var kidTabGap: CGFloat { 12 * s }

    /// S4 board values inside a column: the main column's origin is (64, 176), the side's (930, 176).
    public func s4Main(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: (x - 64) * s, y: (y - 176) * s) }
    public func s4Side(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: (x - 930) * s, y: (y - 176) * s) }
    public func length(_ value: CGFloat) -> CGFloat { value * s }
    /// S4 side summary rows (school, way): text box tops 303 and 396, a 93 pitch.
    public func s4SummaryTop(_ index: Int) -> CGFloat { 303 + 93 * CGFloat(index) }

}
