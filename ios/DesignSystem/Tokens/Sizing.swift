import SwiftUI

/// Turns board values (the 1376 × 1032 boards) into values on any landscape iPad (spec "Sizing
/// formulas"): one scale `s = min(W / 1376, (H − safe.top) / 1008)`, floors for type and spacing
/// (`fluid`), and anchors for x. At 13" every value is the board value.
public struct Sizing: Equatable, Sendable {
    public static let board = CGSize(width: 1376, height: 1032)
    /// The 13" safe-area height the scale is measured against (1032 − the 24 pt status bar).
    public static let referenceHeight: CGFloat = 1008
    /// The band the boards leave empty for the status bar.
    public static let statusBand: CGFloat = 24
    /// Small windows are not designed yet (backlog N8): the scale stops here.
    public static let minimumScale: CGFloat = 0.70

    public let width: CGFloat
    public let height: CGFloat
    public let safeTop: CGFloat
    public let s: CGFloat

    public init(width: CGFloat, height: CGFloat, safeTop: CGFloat = Sizing.statusBand) {
        self.width = width
        self.height = height
        self.safeTop = safeTop
        s = max(Self.minimumScale, min(width / Self.board.width, (height - safeTop) / Self.referenceHeight))
    }

    /// The 13" iPad, where every value is the board value.
    public static let thirteenInch = Sizing(width: 1376, height: 1032)

    /// `max(lo, ref × s)`.
    public func fluid(_ ref: CGFloat, _ lo: CGFloat) -> CGFloat { max(lo, ref * s) }

    /// A board length that scales freely (pictures, drawn parts, region sizes).
    public func scaled(_ ref: CGFloat) -> CGFloat { ref * s }

    /// Screen y of a board y: below the safe top, scaled from the band.
    public func y(_ board: CGFloat) -> CGFloat { safeTop + (board - Self.statusBand) * s }

    /// Screen x of a board x for a region anchored left.
    public func left(_ board: CGFloat) -> CGFloat { board * s }

    /// Screen x of a board x for a region anchored right.
    public func right(_ board: CGFloat) -> CGFloat { width - (Self.board.width - board) * s }

    /// A gap from the spacing tokens: 4, 8 and 12 stay fixed (inside one part); 16, 24, 40 and 64
    /// shrink to 12, 16, 28 and 40 at most.
    public func space(_ ref: CGFloat) -> CGFloat {
        switch ref {
        case ...12: ref
        case 16: fluid(16, 12)
        case 24: fluid(24, 16)
        case 40: fluid(40, 28)
        case 64: fluid(64, 40)
        default: ref * s
        }
    }

    // Grid
    public var margin: CGFloat { fluid(64, 40) }
    public var gutter: CGFloat { fluid(24, 16) }
    public var columnWidth: CGFloat { (width - 2 * margin - 11 * gutter) / 12 }
    /// A region that spans both margins.
    public var stretchWidth: CGFloat { width - 2 * margin }

    /// The size of a crayon type on this screen; caption stays 24.
    public func size(of type: CrayonType) -> CGFloat {
        switch type {
        case .hero: fluid(144, 96)
        case .display: fluid(96, 64)
        case .title: fluid(48, 36)
        case .head: fluid(36, 30)
        case .body: fluid(30, 24)
        case .caption: 24
        }
    }
}

public extension EnvironmentValues {
    /// The screen's sizing, set once at the app root from the window (default: the 13" board).
    @Entry var sizing: Sizing = .thirteenInch
}

public extension Sizing {
    /// The iPad mini screen in landscape: the smallest supported screen and the minimum window
    /// the app asks for (spec "Supported screens and windows").
    static let miniScreen = CGSize(width: 1133, height: 744)

    /// Spec "Supported screens and windows": W and H are the device screen, never the window, so
    /// a Split View or Stage Manager window changes nothing. Before the screen is known (or in
    /// previews) the window stands in.
    static func forScreen(_ screen: CGSize?, window: CGSize, safeTop: CGFloat) -> Sizing {
        let size = screen ?? window
        guard size.width > 0, size.height > 0 else { return .thirteenInch }
        return Sizing(width: size.width, height: size.height, safeTop: safeTop)
    }

    /// A window smaller than the screen keeps the screen's layout, cropped; the hidden part scrolls.
    static func crops(window: CGSize, screen: CGSize?) -> Bool {
        guard let screen, window.width > 0, window.height > 0 else { return false }
        return window.width < screen.width - 0.5 || window.height < screen.height - 0.5
    }
}

extension View {
    /// Hands every view below one `Sizing` built from the device `screen` (spec "Supported screens
    /// and windows"), with the window's safe-area top. A smaller window shows the screen-sized
    /// layout cropped, in a scroll view.
    public func readsSizing(screen: CGSize?) -> some View {
        modifier(SizingReader(screen: screen))
    }
}

private struct SizingReader: ViewModifier {
    let screen: CGSize?
    @State private var window: CGSize = .zero
    @State private var safeTop: CGFloat = Sizing.statusBand

    func body(content: Content) -> some View {
        Group {
            if let screen, Sizing.crops(window: window, screen: screen) {
                ScrollView([.horizontal, .vertical]) {
                    content.frame(width: screen.width, height: screen.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            } else {
                content
            }
        }
        .environment(\.sizing, Sizing.forScreen(screen, window: window, safeTop: safeTop))
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
