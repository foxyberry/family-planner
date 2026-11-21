import CrayonKit
import KitArt
import SwiftUI

/// Picture picker: 88 pt cells, a blue ring on the chosen one (or on each chosen one in multi-pick,
/// spec "Event form rows", Bring), and (when `drawing` is given) a final "+" that asks the
/// child to draw a new picture. Drawings arrive in M6; until then screens leave it out.
public struct IconPicker: View {
    /// The "+" cell: what a tap does.
    public struct Drawing {
        public let action: () -> Void

        public init(action: @escaping () -> Void) {
            self.action = action
        }
    }

    @Environment(\.sizing) private var sizing
    private let isOn: (KitSlot) -> Bool
    private let onTap: (KitSlot) -> Void
    private let slots: [KitSlot]
    private let drawing: Drawing?
    private let columns: Int

    /// One pick. `columns`: 6 under a form's control line; 3 in a 382 side column (C6's new slice).
    public init(selection: Binding<KitSlot?>, slots: [KitSlot], columns: Int = IconPicker.columns,
                drawing: Drawing? = nil) {
        isOn = { $0 == selection.wrappedValue }
        onTap = { selection.wrappedValue = $0 }
        self.slots = slots
        self.columns = columns
        self.drawing = drawing
    }

    /// Several picks: every picked slot has the ring; a tap asks to add or take away that slot (the
    /// caller decides, e.g. up to 4).
    public init(picked: Set<KitSlot>, slots: [KitSlot], columns: Int = IconPicker.columns,
                onToggle: @escaping (KitSlot) -> Void) {
        isOn = { picked.contains($0) }
        onTap = onToggle
        self.slots = slots
        self.columns = columns
        drawing = nil
    }

    /// Cells in a row (board C3: 6 × 88 + 5 × 16 = 608, the form's control width).
    public static let columns = 6

    public var body: some View {
        // Board C3: six 88 cells, 16 apart, from the control line (232 … 840); never centred.
        // Spec "Part floors": cells 88 × s, never under 72.
        let cell = sizing.pictureCircle(88)
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(cell), spacing: Spacing.s), count: columns),
                  alignment: .leading, spacing: Spacing.s) {
            ForEach(Array(slots.enumerated()), id: \.element) { index, slot in
                let isOn = isOn(slot)
                Button { onTap(slot) } label: {
                    KitIcon(slot, size: cell * 64 / 88)
                        .frame(width: cell, height: cell)
                        .background(
                            CrayonSurface(.roundedRect(cornerRadius: 24), fill: CrayonStyle.pictureGround,
                                          markerColor: isOn ? CrayonColor.link : CrayonColor.pictureMarker.opacity(0.25),
                                          seed: CrayonStyle.Seed.iconPicker + UInt32(index))
                        )
                }
                .buttonStyle(.plain)
            }
            if let drawing {
            Button(action: drawing.action) {
                MarkerIcon(.plus, size: 40)
                    .frame(width: 88, height: 88)
                    .partBackground(.roundedRect(cornerRadius: 24), fill: nil, seed: CrayonStyle.Seed.iconPicker + 999)
            }
            .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
