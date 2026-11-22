import CrayonKit
import KitArt
import SwiftUI

/// Picture picker: the 88 picture circles of `ChoiceCircles` (kit art on the picture-ground circle,
/// drawn 76), the pick-blue ring `pickRing` outside the drawn circle (84 on the 13") on the chosen
/// one (or on each chosen one in multi-pick, spec "Event form rows", Bring), and (when `drawing` is
/// given) a final "+" circle that asks the child to draw a new picture. Drawings arrive in M6; until
/// then screens leave it out.
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
    /// The board gap between columns (rows stay 16 apart): 16 under a form's control line, 24 where
    /// four slots spread across a 424 card (spec G1f).
    private var columnGap: CGFloat = Spacing.s

    /// One pick. `columns`: 6 under a form's control line; 3 in a 382 side column (G1's new slice).
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

    /// The same picker with another board gap between columns (spec G1f "More": 24).
    public func columnGap(_ gap: CGFloat) -> IconPicker {
        var copy = self
        copy.columnGap = gap
        return copy
    }

    /// The pick ring's diameter: `pickRing` outside the circle drawn one inset inside its cell.
    static func ringSize(cell: CGFloat, sizing: Sizing) -> CGFloat { cell - 2 * sizing.inset + 2 * sizing.pickRing }

    public var body: some View {
        // Board C3: six 88 cells, 16 apart, from the control line (232 … 840); never centred.
        // Cells 88 × s; art and ring keep their board ratio.
        let cell = sizing(88)
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(cell), spacing: sizing(columnGap)), count: columns),
                  alignment: .leading, spacing: sizing(Spacing.s)) {
            ForEach(Array(slots.enumerated()), id: \.element) { index, slot in
                let isOn = isOn(slot)
                Button { onTap(slot) } label: {
                    KitIcon(slot, size: cell * 64 / 88)
                        .frame(width: cell, height: cell)
                        .partBackground(.circle, fill: CrayonStyle.pictureGround,
                                        seed: CrayonStyle.Seed.iconPicker + UInt32(index),
                                        markerColor: CrayonColor.pictureOutline)
                        .overlay {
                            if isOn {
                                // As ChoiceCircles: the ring sits `pickRing` outside the drawn circle.
                                Circle().stroke(CrayonColor.pickBlue, lineWidth: sizing(5))
                                    .frame(width: Self.ringSize(cell: cell, sizing: sizing),
                                           height: Self.ringSize(cell: cell, sizing: sizing))
                            }
                        }
                }
                .buttonStyle(.plain)
            }
            if let drawing {
                Button(action: drawing.action) {
                    MarkerIcon(.plus, size: cell * 40 / 88)
                        .frame(width: cell, height: cell)
                        .partBackground(.circle, fill: nil, seed: CrayonStyle.Seed.iconPicker + 999)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
