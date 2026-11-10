import CoreGraphics

/// The grown-up boards' shared lines (family `grown`, layout v31: G1–G8, C2, C3, C3g, C4, E5, C5,
/// S1–S4 in docs/superpowers/layout) through "Sizing formulas". Every grown-up screen places its
/// frame from here: 40 side margins like home, the header band 48–128 (← at 40, title at 144), the
/// form card 40–840 (left-anchored; labels at 80, controls at 208), the side column 864–1336
/// (right-anchored, 472 wide) and the action button (864, 872, 472 × 96) ending on 968.
public struct GrownupLayout: Equatable, Sendable {
    public let sizing: Sizing

    public init(sizing: Sizing) {
        self.sizing = sizing
    }

    private var s: CGFloat { sizing.s }

    // Header (48–128)
    public var back: CGRect { sizing.left(40, 48, 80, 80) }
    /// The title starts 24 after the ← button.
    public var titleGap: CGFloat { 24 * s }
    /// Header text sits on 107; the right-hand note ("Grown-ups only") on 97, ending on 1336.
    public var headerBaseline: CGFloat { sizing.y(107) }
    public var right: CGFloat { sizing.right(1336) }

    // Form card (40–840 × 176–968) and its inner columns.
    public var form: CGRect { CGRect(x: sizing.left(40), y: sizing.y(176), width: (840 - 40) * s, height: (968 - 176) * s) }
    /// Rows start 40 inside the card (x 80) and end 40 before its right edge (800).
    public var formInset: CGFloat { 40 * s }
    public var labelLeft: CGFloat { sizing.left(80) }
    /// Form controls start on 208 (C3, C4, E5); a label column is 208 − 80 wide.
    public var controlLeft: CGFloat { sizing.left(208) }
    public var labelWidth: CGFloat { controlLeft - labelLeft }
    /// G6 "About" values start on 256.
    public var valueLeft: CGFloat { sizing.left(256) }

    // Side column (864–1336, right-anchored) and the action button at its foot.
    public var side: CGRect {
        CGRect(x: sizing.right(864), y: sizing.y(176), width: (1336 - 864) * s, height: (968 - 176) * s)
    }
    public var action: CGRect { sizing.right(864, 872, 472, 96) }
    /// Between the card and the side column (24 on the 13", wider on smaller iPads).
    public var gap: CGFloat { side.minX - form.maxX }

    /// Content top 176 and the bottom 968, as distances the frame pads by.
    public var contentTop: CGFloat { sizing.y(176) }
    public var bottomInset: CGFloat { sizing.height - sizing.y(968) }
}
