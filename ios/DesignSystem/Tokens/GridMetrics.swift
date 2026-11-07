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

    public init(width: CGFloat) {
        self.width = width
    }

    public var columnWidth: CGFloat {
        (width - 2 * Self.margin - CGFloat(Self.columns - 1) * Self.gutter) / CGFloat(Self.columns)
    }

    /// Width of `n` columns including the gutters between them.
    public func span(_ n: Int) -> CGFloat {
        CGFloat(n) * columnWidth + CGFloat(max(n - 1, 0)) * Self.gutter
    }

    /// Left edge of the column at zero-based index `column`.
    public func x(column: Int) -> CGFloat {
        Self.margin + CGFloat(column) * (columnWidth + Self.gutter)
    }
}
