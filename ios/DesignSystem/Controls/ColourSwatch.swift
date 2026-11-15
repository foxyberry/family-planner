import CrayonKit
import SwiftUI

/// A kid colour to pick (board S1 "Colour"): a 56 crayon circle in the colour; the picked one has
/// the pick-blue ring (72). Colour never carries meaning alone: the screen labels the row.
public struct ColourSwatch: View {
    private let colorIndex: Int
    private let isPicked: Bool
    private let accessibilityLabel: String
    private let action: () -> Void
    /// The circle's diameter (56 on the board; the screen's scale on a smaller iPad). The touch area
    /// is 16 wider, the pick ring 10.
    private let size: CGFloat

    public init(colorIndex: Int, isPicked: Bool, accessibilityLabel: String, size: CGFloat = 56,
                action: @escaping () -> Void) {
        self.size = size
        self.colorIndex = colorIndex
        self.isPicked = isPicked
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            CrayonSurface(.circle, fill: CrayonStyle.kid(colorIndex), markerColor: CrayonColor.marker,
                          seed: CrayonStyle.Seed.swatch + UInt32(max(colorIndex, 0)))
                .frame(width: size, height: size)
                .overlay {
                    if isPicked {
                        // Board S1: the pick ring hugs the swatch.
                        Circle().stroke(CrayonColor.pickBlue, lineWidth: 5).frame(width: size + 10, height: size + 10)
                    }
                }
                .frame(width: size + 16, height: size + 16)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isPicked ? [.isButton, .isSelected] : .isButton)
    }
}
