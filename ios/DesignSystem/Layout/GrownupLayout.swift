import CoreGraphics

/// The grown-up boards' shared lines (family `grown`: G1–G8, C2, C3, C3g, C4, C5, S1–S4 in
/// docs/superpowers/layout), each board value × s (spec "Sizing: one scale, no floors").
/// Every grown-up screen places its
/// frame from here: 40 side margins like home, the header band 44–124 (layout v32: ← at 40, 44, on
/// the home pencil's row; title at 144), the form card 40–840 × 148–968 (labels at 78, controls at
/// 192, right edge 808), the side column 864–1336 (472 wide) and the action button (864, 872,
/// 472 × 96) ending on 968.
public struct GrownupLayout: Equatable, Sendable {
    public let sizing: Sizing
    /// The keyboard's top edge on screen while it is open (board C3k), else nil.
    public let keyboardTop: CGFloat?

    public init(sizing: Sizing, keyboardTop: CGFloat? = nil) {
        self.sizing = sizing
        self.keyboardTop = keyboardTop
    }

    /// Board C3k: with the keyboard open the form card and the action button end 28 above it; the
    /// header and the side column's top stay where they are.
    private var bottom: CGFloat {
        let board = sizing.y(968)
        guard let keyboardTop else { return board }
        return min(board, keyboardTop - 28 * s)
    }

    private var s: CGFloat { sizing.s }

    // Header (44–124, layout v32)
    public var back: CGRect { sizing.rect(40, 44, 80, 80) }
    /// The title starts 24 after the ← button.
    public var titleGap: CGFloat { 24 * s }
    /// Header text sits on 103; the right-hand note ("Grown-ups only") ends on 1336.
    public var headerBaseline: CGFloat { sizing.y(103) }
    public var right: CGFloat { sizing.x(1336) }

    // Form card (40–840 × 148–968) and its inner columns.
    public var form: CGRect {
        CGRect(x: sizing.x(40), y: sizing.y(148), width: (840 - 40) * s, height: max(bottom - sizing.y(148), 96 * s))
    }
    /// Spec "Layout balance": the card pads 32 from its drawn edge, so rows start on the label line
    /// (card + 38, board 78) and end on the right-edge line (card right − 32, 808).
    public var formInset: CGFloat { sizing.cardPadding.leading }
    public var labelLeft: CGFloat { form.minX + formInset }
    /// One label column (114) on every grown-up form: controls start on 192.
    public var controlLeft: CGFloat { labelLeft + labelWidth }
    public var labelWidth: CGFloat { FormLines.labelColumn * s }
    /// The right-edge line: stretching controls end here (drawn 802).
    public var rightEdge: CGFloat { form.maxX - sizing.cardPadding.trailing }
    /// The control column of a form row: the control line to the right edge (616 on the 13").
    public var controlWidth: CGFloat { rightEdge - controlLeft }
    /// A form card's rows, label line to right edge (730 on the 13").
    public var editorRowsWidth: CGFloat { rightEdge - labelLeft }
    /// G6 "About" values start on 256.
    public var valueLeft: CGFloat { sizing.x(256) }

    // Side column (864–1336) and the action button at its foot.
    public var side: CGRect {
        CGRect(x: sizing.x(864), y: sizing.y(148), width: (1336 - 864) * s, height: (968 - 148) * s)
    }
    public var action: CGRect {
        let board = sizing.rect(864, 872, 472, 96)
        return CGRect(x: board.minX, y: max(bottom, sizing.y(148) + board.height) - board.height,
                      width: board.width, height: board.height)
    }
    /// Between the card and the side column (24 × s).
    public var gap: CGFloat { side.minX - form.maxX }

    /// Content top 148 and the bottom 968, as distances the frame pads by.
    public var contentTop: CGFloat { sizing.y(148) }
    public var bottomInset: CGFloat { sizing.height - bottom }
}
