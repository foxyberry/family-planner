import CoreGraphics

/// The grown-up boards' shared lines (family `grown`, layout v31: G1–G8, C2, C3, C3g, C4, E5, C5,
/// S1–S4 in docs/superpowers/layout) through "Sizing formulas". Every grown-up screen places its
/// frame from here: 40 side margins like home, the header band 44–124 (layout v32: ← at 40, 44, on
/// the home pencil's row; title at 144), the form card 40–840 × 148–968 (left-anchored; labels at 80, controls at 208), the side column 864–1336
/// (right-anchored, 472 wide) and the action button (864, 872, 472 × 96) ending on 968.
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
    public var back: CGRect { sizing.left(40, 44, 80, 80) }
    /// The title starts 24 after the ← button.
    public var titleGap: CGFloat { 24 * s }
    /// Header text sits on 103; the right-hand note ("Grown-ups only") ends on 1336.
    public var headerBaseline: CGFloat { sizing.y(103) }
    public var right: CGFloat { sizing.right(1336) }

    // Form card (40–840 × 148–968) and its inner columns.
    /// On an iPad wider than the board at its scale (the 11": height sets the scale) the spare width
    /// goes to the card, so it ends 24 × s before the side column as on the 13" (user, 2026-11-15).
    public var form: CGRect {
        CGRect(x: sizing.left(40), y: sizing.y(148), width: max((840 - 40) * s, sizing.right(864) - 24 * s - sizing.left(40)),
               height: max(bottom - sizing.y(148), 96 * s))
    }
    /// Rows start 40 inside the card (x 80) and end 40 before its right edge (800).
    /// Spec "Part floors": 40, never under 28.
    public var formInset: CGFloat { sizing.formCardInset }
    public var labelLeft: CGFloat { sizing.left(80) }
    /// Form controls start on 208 (C3, C4, E5); a label column is 208 − 80 wide.
    public var controlLeft: CGFloat { sizing.left(208) }
    public var labelWidth: CGFloat { controlLeft - labelLeft }
    /// The control column of a form row: 208 to 40 inside the card's right edge (592).
    public var controlWidth: CGFloat { form.width - formInset - (controlLeft - form.minX) }
    /// The editor boards (C3, C4, E5, G2–G4) run their rows to 818: six "What" circles end on 816,
    /// the name field on 818. Their card keeps 40 on the left and only 22 on the right.
    public var editorTrailingInset: CGFloat { 22 * s }
    public var editorRowsWidth: CGFloat { form.width - formInset - editorTrailingInset }
    /// G6 "About" values start on 256.
    public var valueLeft: CGFloat { sizing.left(256) }

    // Side column (864–1336, right-anchored) and the action button at its foot.
    public var side: CGRect {
        CGRect(x: sizing.right(864), y: sizing.y(148), width: (1336 - 864) * s, height: (968 - 148) * s)
    }
    public var action: CGRect {
        let board = sizing.right(864, 872, 472, 96)
        return CGRect(x: board.minX, y: max(bottom, sizing.y(148) + board.height) - board.height,
                      width: board.width, height: board.height)
    }
    /// Between the card and the side column (24 × s on every iPad).
    public var gap: CGFloat { side.minX - form.maxX }

    /// Content top 148 and the bottom 968, as distances the frame pads by.
    public var contentTop: CGFloat { sizing.y(148) }
    public var bottomInset: CGFloat { sizing.height - bottom }
}
