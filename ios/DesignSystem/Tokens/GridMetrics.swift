import CoreGraphics

/// The 12-column grid, computed from the real screen width (the design is 1376 pt wide,
/// the 12.9-inch iPad Pro is 1366 pt), so nothing uses fixed pixel positions.
public struct GridMetrics: Equatable, Sendable {
    public static let margin: CGFloat = 64
    public static let gutter: CGFloat = 24
    public static let columns = 12
    public static let headerTop: CGFloat = 48
    public static let headerBottom: CGFloat = 128
    public static let contentTop: CGFloat = 176
    public static let contentBottomInset: CGFloat = 64

    public let width: CGFloat
    /// This screen's margin and gutter (board 64 and 24; smaller iPads use `Sizing`'s floors).
    public let screenMargin: CGFloat
    public let screenGutter: CGFloat

    public init(width: CGFloat, margin: CGFloat = GridMetrics.margin, gutter: CGFloat = GridMetrics.gutter) {
        self.width = width
        screenMargin = margin
        screenGutter = gutter
    }

    /// The grid for a screen as wide as `width`, with the margin and gutter of `sizing`.
    public init(width: CGFloat, sizing: Sizing) {
        self.init(width: width, margin: sizing.margin, gutter: sizing.gutter)
    }

    public var columnWidth: CGFloat {
        (width - 2 * screenMargin - CGFloat(Self.columns - 1) * screenGutter) / CGFloat(Self.columns)
    }

    /// Width of `n` columns including the gutters between them.
    public func span(_ n: Int) -> CGFloat {
        CGFloat(n) * columnWidth + CGFloat(max(n - 1, 0)) * screenGutter
    }

    /// Left edge of the column at zero-based index `column`.
    public func x(column: Int) -> CGFloat {
        screenMargin + CGFloat(column) * (columnWidth + screenGutter)
    }
}
