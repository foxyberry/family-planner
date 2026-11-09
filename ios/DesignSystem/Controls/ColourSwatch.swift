import CrayonKit
import SwiftUI

/// A kid colour to pick (board S1 "Colour"): a 56 crayon circle in the colour; the picked one has
/// the pick-blue ring (72). Colour never carries meaning alone: the screen labels the row.
public struct ColourSwatch: View {
    private let colorIndex: Int
    private let isPicked: Bool
    private let accessibilityLabel: String
    private let action: () -> Void

    public init(colorIndex: Int, isPicked: Bool, accessibilityLabel: String, action: @escaping () -> Void) {
        self.colorIndex = colorIndex
        self.isPicked = isPicked
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            CrayonSurface(.circle, fill: CrayonStyle.kid(colorIndex), markerColor: CrayonColor.marker,
                          seed: CrayonStyle.Seed.swatch + UInt32(max(colorIndex, 0)))
                .frame(width: 56, height: 56)
                .overlay {
                    if isPicked {
                        // Board S1: the pick ring hugs the swatch.
                        Circle().stroke(CrayonColor.pickBlue, lineWidth: 5).frame(width: 66, height: 66)
                    }
                }
                .frame(width: 72, height: 72)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isPicked ? [.isButton, .isSelected] : .isButton)
    }
}
