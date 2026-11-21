import CrayonKit
import SwiftUI

/// Spec "Sizing: one scale, no floors": every screen is the 1376 × 1032 board scaled as one picture.
/// One scale `s = min(W / 1376, (H − safe.top) / 1008)` from the app window, and every size is the
/// board value × s: positions, frames, gaps, padding, controls, touch areas, pictures, strokes and
/// type. Nothing is floored or kept fixed, so at s = 1 every value is the board value.
///
/// Screens lay out inside the board frame, `width` (1376 s) wide and the window's height, which the
/// app root centres in the window; the leftover on each side (`bleed`) is paper (night sky at night).
public struct Sizing: Equatable, Sendable {
    public static let board = CGSize(width: 1376, height: 1032)
    /// The 13" safe-area height the scale is measured against (1032 − the 24 pt status bar).
    public static let referenceHeight: CGFloat = 1008
    /// The band the boards leave empty for the status bar.
    public static let statusBand: CGFloat = 24

    /// The app window (landscape; full screen, Split View or Stage Manager).
    public let window: CGSize
    public let safeTop: CGFloat
    public let s: CGFloat

    /// `width` × `height` is the window; `safeTop` the top safe-area inset it reports.
    public init(width: CGFloat, height: CGFloat, safeTop: CGFloat = Sizing.statusBand) {
        window = CGSize(width: width, height: height)
        self.safeTop = safeTop
        s = min(width / Self.board.width, (height - safeTop) / Self.referenceHeight)
    }

    /// The 13" iPad, where every value is the board value.
    public static let thirteenInch = Sizing(width: 1376, height: 1032)

    /// The window's sizing; before the window is known (zero size) the 13" stands in.
    public static func forWindow(_ window: CGSize, safeTop: CGFloat) -> Sizing {
        guard window.width > 0, window.height > 0 else { return .thirteenInch }
        return Sizing(width: window.width, height: window.height, safeTop: safeTop)
    }

    /// The board frame screens lay out in: the board's width × s, centred in the window.
    public var width: CGFloat { Self.board.width * s }
    /// The window's height: the board's top sits on `safeTop`; the space under it is paper.
    public var height: CGFloat { window.height }
    /// The paper left over on each side of the board frame (0 when the width sets the scale).
    public var bleed: CGFloat { max(0, (window.width - width) / 2) }

    /// A board length on this screen: `board × s`.
    public func callAsFunction(_ board: CGFloat) -> CGFloat { board * s }

    /// A board size on this screen.
    public func callAsFunction(_ width: CGFloat, _ height: CGFloat) -> CGSize { CGSize(width: width * s, height: height * s) }

    /// Screen x of a board x, in the board frame.
    public func x(_ board: CGFloat) -> CGFloat { board * s }

    /// Screen y of a board y: below the safe top, scaled from the band.
    public func y(_ board: CGFloat) -> CGFloat { safeTop + (board - Self.statusBand) * s }

    /// A board rect on this screen.
    public func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: self.x(x), y: self.y(y), width: w * s, height: h * s)
    }

    /// The size of a crayon type on this screen: the board size × s, fractional.
    public func size(of type: CrayonType) -> CGFloat { type.size * s }
}

public extension EnvironmentValues {
    /// The screen's sizing, set once at the app root from the window (default: the 13" board).
    @Entry var sizing: Sizing = .thirteenInch
}

extension View {
    /// Hands every view below `sizing`, and the crayon parts its scale (outlines and hatching are
    /// drawn in board units and scaled with the part).
    public func withSizing(_ sizing: Sizing) -> some View {
        environment(\.sizing, sizing).environment(\.crayonScale, sizing.s)
    }

    /// Hands every view below one `Sizing` built from the app window (spec "Supported screens and
    /// windows"), worked out again whenever the window changes size, and centres the board frame
    /// (1376 s wide) in the window. Paper fills the sides (`fullBleed()`).
    public func readsSizing() -> some View {
        modifier(SizingReader())
    }

    /// A full-bleed background (paper, night sky, the dim layer): it fills the window, past the board
    /// frame's sides and under the status bar.
    public func fullBleed() -> some View {
        modifier(FullBleed())
    }
}

private struct FullBleed: ViewModifier {
    @Environment(\.sizing) private var sizing

    func body(content: Content) -> some View {
        content.padding(.horizontal, -sizing.bleed).ignoresSafeArea()
    }
}

private struct SizingReader: ViewModifier {
    @State private var window: CGSize = .zero
    @State private var safeTop: CGFloat = Sizing.statusBand

    func body(content: Content) -> some View {
        let sizing = Sizing.forWindow(window, safeTop: safeTop)
        content
            .withSizing(sizing)
            .frame(width: sizing.width)
            .frame(maxWidth: .infinity)
            // The window's whole size (ignoring the safe area), and the top inset (the status bar
            // and, on iPadOS 26, the window controls) from a reader that keeps it.
            .background {
                GeometryReader { full in
                    Color.clear.onAppear { window = full.size }.onChange(of: full.size) { _, size in window = size }
                }
                .ignoresSafeArea()
            }
            .background {
                GeometryReader { safe in
                    Color.clear.onAppear { safeTop = safe.safeAreaInsets.top }
                        .onChange(of: safe.safeAreaInsets.top) { _, top in safeTop = top }
                }
            }
    }
}
