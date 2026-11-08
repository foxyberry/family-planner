import CoreGraphics

/// The grown-up boards' shared lines (C1, E6, C2, C3, C3g, C4, E5, C5, C6 in
/// docs/superpowers/layout) through "Sizing formulas". Every grown-up screen places its frame from
/// here: the header band 48–128 (← at 64, title at 168), the form card 64–882 (left-anchored; labels
/// at 104, controls at 232), the side column 930–1312 (right-anchored) and the action button
/// (930, 872, 382 × 96) ending on 968.
public struct GrownupLayout: Equatable, Sendable {
    public let sizing: Sizing

    public init(sizing: Sizing) {
        self.sizing = sizing
    }

    private var s: CGFloat { sizing.s }

    // Header (48–128)
    public var back: CGRect { sizing.left(64, 48, 80, 80) }
    /// The title starts 24 after the ← button.
    public var titleGap: CGFloat { 24 * s }
    /// Header text sits on 107; the right-hand note ("Grown-ups only") on 97, ending on 1312.
    public var headerBaseline: CGFloat { sizing.y(107) }
    public var right: CGFloat { sizing.right(1312) }

    // Form card (64–882 × 176–968) and its inner columns.
    public var form: CGRect { CGRect(x: sizing.left(64), y: sizing.y(176), width: (882 - 64) * s, height: (968 - 176) * s) }
    /// Rows start 40 inside the card (x 104) and end 40 before its right edge (842).
    public var formInset: CGFloat { 40 * s }
    public var labelLeft: CGFloat { sizing.left(104) }
    /// Form controls start on 232 (C3, C4, E5); a label column is 232 − 104 wide.
    public var controlLeft: CGFloat { sizing.left(232) }
    public var labelWidth: CGFloat { controlLeft - labelLeft }
    /// C1 / E6 "About" values start on 280.
    public var valueLeft: CGFloat { sizing.left(280) }

    // Side column (930–1312, right-anchored) and the action button at its foot.
    public var side: CGRect {
        CGRect(x: sizing.right(930), y: sizing.y(176), width: (1312 - 930) * s, height: (968 - 176) * s)
    }
    public var action: CGRect { sizing.right(930, 872, 382, 96) }
    /// Between the card and the side column (48 on the 13", wider on smaller iPads).
    public var gap: CGFloat { side.minX - form.maxX }

    /// Content top 176 and the bottom 968, as distances the frame pads by.
    public var contentTop: CGFloat { sizing.y(176) }
    public var bottomInset: CGFloat { sizing.height - sizing.y(968) }
}
