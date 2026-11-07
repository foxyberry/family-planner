import CrayonKit
import KitArt
import SwiftUI

/// Picture picker: 88 pt cells, a blue ring on the chosen one, and a final "+" that asks the
/// child to draw a new picture.
public struct IconPicker: View {
    @Binding private var selection: KitSlot?
    private let slots: [KitSlot]
    private let onRequestDrawing: () -> Void

    public init(selection: Binding<KitSlot?>, slots: [KitSlot], onRequestDrawing: @escaping () -> Void) {
        _selection = selection
        self.slots = slots
        self.onRequestDrawing = onRequestDrawing
    }

    public var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88, maximum: 88), spacing: Spacing.s)], spacing: Spacing.s) {
            ForEach(Array(slots.enumerated()), id: \.element) { index, slot in
                let isOn = slot == selection
                Button { selection = slot } label: {
                    KitIcon(slot, size: 64)
                        .frame(width: 88, height: 88)
                        .background(
                            CrayonSurface(.roundedRect(cornerRadius: 24), fill: CrayonStyle.paper,
                                          markerColor: isOn ? CrayonColor.link : CrayonColor.marker.opacity(0.25),
                                          seed: CrayonStyle.Seed.iconPicker + UInt32(index))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(slot.rawValue)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
            Button(action: onRequestDrawing) {
                Image(systemName: "plus")
                    .font(CrayonType.head.font.weight(.bold))
                    .foregroundStyle(CrayonColor.ink)
                    .frame(width: 88, height: 88)
                    .crayonBackground(.roundedRect(cornerRadius: 24), fill: nil, seed: CrayonStyle.Seed.iconPicker + 999)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Draw a new picture")
        }
    }
}
