import CrayonKit
import KitArt
import SwiftUI

/// Board C3 "What" (layout v6): one row of picture slots (88, gap 16; the picked one has a blue
/// ring), then a "More" slot (88 circle, bold caption). "More" opens a card under the row with every
/// picture, 6 per row (`IconPicker`); the row never wraps or scrolls, so the rows below keep their
/// lines. Callers pass the slots (the picked one first) and the words.
public struct PictureRow: View {
    private let slots: [KitSlot]
    @Binding private var selection: KitSlot?
    private let all: [KitSlot]
    private let isShowingAll: Bool
    private let moreTitle: String
    private let moreLabel: String
    private let onMore: () -> Void

    public init(slots: [KitSlot], selection: Binding<KitSlot?>, all: [KitSlot], isShowingAll: Bool,
                moreTitle: String, moreLabel: String, onMore: @escaping () -> Void) {
        self.slots = slots
        _selection = selection
        self.all = all
        self.isShowingAll = isShowingAll
        self.moreTitle = moreTitle
        self.moreLabel = moreLabel
        self.onMore = onMore
    }

    public var body: some View {
        HStack(spacing: Spacing.s) {
            ForEach(Array(slots.enumerated()), id: \.element) { index, slot in
                let isOn = slot == selection
                Button { selection = slot } label: {
                    // Boards C3/C4: 88 paper circles with an ink outline; the picked one gets a 104
                    // blue ring around it.
                    KitIcon(slot, size: 64)
                        .frame(width: 88, height: 88)
                        .background(
                            CrayonSurface(.circle, fill: CrayonStyle.paper,
                                          seed: CrayonStyle.Seed.iconPicker + UInt32(index))
                                .padding(CrayonStyle.artInset)
                        )
                        .overlay {
                            if isOn {
                                CrayonSurface(.circle, fill: nil, markerColor: CrayonColor.link,
                                              seed: CrayonStyle.Seed.iconPicker + 500 + UInt32(index))
                                    .frame(width: 104, height: 104)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(slot.rawValue)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
            Button(action: onMore) {
                Text(moreTitle).crayonType(.caption, bold: true).foregroundStyle(CrayonColor.ink)
                    .frame(width: 88, height: 88)
                    .crayonBackground(.circle, fill: CrayonStyle.paper, seed: CrayonStyle.Seed.iconPicker + 998)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(moreLabel)
            .accessibilityAddTraits(isShowingAll ? .isSelected : [])
            .overlay(alignment: .topTrailing) {
                if isShowingAll {
                    // Under the "More" slot, its right edge on the slot's: every picture, 6 per row.
                    PaperCard(seed: 97) { IconPicker(selection: $selection, slots: all) }
                        .fixedSize()
                        .offset(y: 88 + Spacing.sm)
                }
            }
        }
    }
}
