import CrayonKit
import SwiftUI

/// A kid colour to pick (board S1 "Colour"): a 56 crayon circle in the colour; the picked one has
/// the pick-blue ring (72), drawn as an overlay. Colour never carries meaning alone: the screen
/// labels the row. Spec "Layout model": the frame is the circle plus one crayon inset each side
/// (68 on the 13"), so the frame sits on the control line and the circle 6 inside it.
public struct ColourSwatch: View {
    private let colorIndex: Int
    private let isPicked: Bool
    private let accessibilityLabel: String
    private let action: () -> Void
    @Environment(\.sizing) private var sizing
    /// Spec "Part floors": 56 × s, never under 48.
    private var size: CGFloat { sizing.swatch }

    public init(colorIndex: Int, isPicked: Bool, accessibilityLabel: String, action: @escaping () -> Void) {
        self.colorIndex = colorIndex
        self.isPicked = isPicked
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    /// The swatch's frame on `sizing` (its row lays out four of these, 12 apart).
    public static func frame(_ sizing: Sizing) -> CGFloat { sizing.swatch + 2 * CrayonPart.inset }

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
                .frame(width: Self.frame(sizing), height: Self.frame(sizing))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isPicked ? [.isButton, .isSelected] : .isButton)
    }
}
