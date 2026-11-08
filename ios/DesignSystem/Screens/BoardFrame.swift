import SwiftUI

/// The board as the screen (spec "Board = screen"): content is laid out in the boards' 1376 × 1032
/// frame in full-screen space, y 0 at the top of the glass, not the safe area. The boards keep the
/// status bar band (y 0–24) empty, so the bar sits over empty paper. Other sizes scale the whole
/// frame by min(W / 1376, H / 1032), top-aligned and centred across (12.9": 0.992). Content that
/// does not fit is clipped; it never grows, centres or moves the frame.
public struct BoardFrame<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        GeometryReader { geometry in
            content
                .frame(width: BoardMetrics.size.width, height: BoardMetrics.size.height, alignment: .topLeading)
                .clipped()
                .scaleEffect(BoardMetrics.scale(for: geometry.size), anchor: .top)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .ignoresSafeArea()
    }
}

extension View {
    /// Lays the view out as a full board (see `BoardFrame`).
    public func boardFrame() -> some View {
        BoardFrame { self }
    }
}

/// The board's size and the status bar band it leaves empty.
public enum BoardMetrics {
    public static let size = CGSize(width: 1376, height: 1032)
    public static let statusBand: CGFloat = 24

    /// Uniform scale of the board on a screen of `screen` points.
    public static func scale(for screen: CGSize) -> CGFloat {
        min(screen.width / size.width, screen.height / size.height)
    }
}
