import CoreGraphics
import DesignSystem

/// Boards K1, K1o and K1n (docs/superpowers/layout, v82; spec K1 "Layout"), every board value × s
/// (spec "Sizing: one scale, no floors"). The K1 files were exported under the morning family's
/// region names, so these come from their element boxes and the spec, not their `lines`.
public struct SchoolYearLayout: Equatable, Sendable {
    public let sizing: Sizing

    public init(sizing: Sizing) {
        self.sizing = sizing
    }

    // MARK: Header (44–124)

    /// "‹" `RoundButton` 80 at (40, 44).
    public var back: CGRect { sizing.rect(40, 44, 80, 80) }
    /// The year tabs, 150 × 72 with 12 between, from x 144, on the header's middle (48–120).
    public var tabs: CGPoint { CGPoint(x: sizing.x(144), y: sizing.y(48)) }
    public static let tabSize = CGSize(width: 150, height: 72)
    public static let tabGap: CGFloat = 12
    /// The legend column, x 480–1336, y 44–124 (two lines at most).
    public var legend: CGRect { sizing.rect(480, 44, 1336 - 480, 80) }

    // MARK: Month cards

    /// Twelve cards 312 × 268, four across and three down, 16 apart across and 12 down, from (40, 148).
    public func card(_ index: Int) -> CGRect {
        let column = CGFloat(index % 4), row = CGFloat(index / 4)
        return sizing.rect(40 + column * (312 + 16), 148 + row * (268 + 12), 312, 268)
    }

    // MARK: The open month (board K1o)

    /// Layout v82: 1200 × 800 at (88, 160), the grid on the left and the days-off names on the right.
    public var openCard: CGRect { sizing.rect(88, 160, 1200, 800) }
    /// Its "×", `RoundButton` 72, 40 in from the card's right and 24 down.
    public var openClose: CGRect { sizing.rect(88 + 1200 - 40 - 72, 160 + 24, 72, 72) }
}
