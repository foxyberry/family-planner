import CoreGraphics
import DesignSystem

/// Boards S1–S4 (layout v10) on the grown-up lines (`GrownupLayout`) through "Sizing formulas":
/// the header ends on 1336 like every grown-up header (layout v31); S1 kid cards follow `FormLines`
/// (layout v55); S4 rows are 120 tall on a 140 pitch from 188.
public struct SetupLayout: Equatable, Sendable {
    public let grown: GrownupLayout

    public init(sizing: Sizing) {
        grown = GrownupLayout(sizing: sizing)
    }

    private var sizing: Sizing { grown.sizing }
    private var s: CGFloat { sizing.s }

    /// S2 and S3: the school field 610 wide, the stop field 400.
    public var schoolFieldWidth: CGFloat { 610 * s }

    /// S2 and S3 kid tabs (layout v17): 200 × 72 with the name, 88 × 72 face only; gap 12.
    public func kidTab(faceOnly: Bool) -> CGSize { CGSize(width: (faceOnly ? 88 : 200) * s, height: 72 * s) }
    public var kidTabGap: CGFloat { 12 * s }

    /// S4 board values inside a column: the main column's origin is (40, 148), the side's (864, 148)
    /// (layout v32).
    public func s4Side(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: (x - 864) * s, y: (y - 148) * s) }
    public func length(_ value: CGFloat) -> CGFloat { value * s }
    /// S4 side summary rows (school, way): text box tops 275 and 368, a 93 pitch.
    public func s4SummaryTop(_ index: Int) -> CGFloat { 275 + 93 * CGFloat(index) }

}
