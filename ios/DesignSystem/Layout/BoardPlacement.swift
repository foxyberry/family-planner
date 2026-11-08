import SwiftUI

/// One way to put a part on a screen (spec "Sizing formulas", "Fixed regions"): every screen is
/// a `ZStack(alignment: .topLeading)` the size of the window, and every part is placed at a rect
/// worked out from board values by `Sizing`. Parts carry no outer padding, so a rect's edge is the
/// part's visible edge and parts on the same board line line up.
extension View {
    /// The part fills `rect` (screen points, top-left origin).
    public func place(_ rect: CGRect) -> some View {
        frame(width: max(rect.width, 0), height: max(rect.height, 0))
            .offset(x: rect.minX, y: rect.minY)
    }

    /// A part at its own size with its top-left corner at `point`.
    public func place(topLeft point: CGPoint) -> some View {
        Color.clear.frame(width: 0, height: 0)
            .overlay(alignment: .topLeading) { fixedSize() }
            .offset(x: point.x, y: point.y)
    }

    /// A text (or a row of texts) whose left edge is `x` and whose first baseline is `baseline`.
    /// It hangs off a zero-size anchor, so it never moves the screen's other parts.
    public func place(left x: CGFloat, baseline: CGFloat) -> some View {
        Color.clear.frame(width: 0, height: 0)
            .overlay(alignment: Alignment(horizontal: .leading, vertical: .firstTextBaseline)) { fixedSize() }
            .offset(x: x, y: baseline)
    }

    /// A text (or a row of texts) whose right edge is `x` and whose first baseline is `baseline`.
    public func place(right x: CGFloat, baseline: CGFloat) -> some View {
        Color.clear.frame(width: 0, height: 0)
            .overlay(alignment: Alignment(horizontal: .trailing, vertical: .firstTextBaseline)) { fixedSize() }
            .offset(x: x, y: baseline)
    }
}

extension Sizing {
    /// A board rect anchored left: x and widths scale by s.
    public func left(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: left(x), y: self.y(y), width: w * s, height: h * s)
    }

    /// A board rect anchored right: its right edge keeps its distance from the window's right.
    public func right(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: right(x + w) - w * s, y: self.y(y), width: w * s, height: h * s)
    }

    /// A board rect that stretches between two board lines: `from` left-anchored, `to`
    /// right-anchored (a region spanning both sides grows with the window).
    public func stretch(from: CGFloat, to: CGFloat, _ y: CGFloat, _ h: CGFloat) -> CGRect {
        let minX = left(from), maxX = right(to)
        return CGRect(x: minX, y: self.y(y), width: maxX - minX, height: h * s)
    }
}
