import CrayonKit
import KitArt
import Strings
import SwiftUI

/// Picture picker: 88 pt cells, a blue ring on the chosen one, and (when `onRequestDrawing` is
/// given) a final "+" that asks the child to draw a new picture. Drawings arrive in M6; until then
/// screens leave it out.
public struct IconPicker: View {
    @Binding private var selection: KitSlot?
    private let slots: [KitSlot]
    private let onRequestDrawing: (() -> Void)?
    private let columns: Int

    /// `columns`: 6 under a form's control line; 3 in a 382 side column (C6's new slice).
    public init(selection: Binding<KitSlot?>, slots: [KitSlot], columns: Int = IconPicker.columns,
                onRequestDrawing: (() -> Void)? = nil) {
        _selection = selection
        self.slots = slots
        self.columns = columns
        self.onRequestDrawing = onRequestDrawing
    }

    /// Cells in a row (board C3: 6 × 88 + 5 × 16 = 608, the form's control width).
    public static let columns = 6

    public var body: some View {
        // Board C3: six 88 cells, 16 apart, from the control line (232 … 840); never centred.
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(88), spacing: Spacing.s), count: columns),
                  alignment: .leading, spacing: Spacing.s) {
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
            if let onRequestDrawing {
            Button(action: onRequestDrawing) {
                MarkerIcon(.plus, size: 40)
                    .frame(width: 88, height: 88)
                    .partBackground(.roundedRect(cornerRadius: 24), fill: nil, seed: CrayonStyle.Seed.iconPicker + 999)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.tr("picker.draw"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
