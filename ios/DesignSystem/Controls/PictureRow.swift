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
    private let onMore: () -> Void
    /// Board G1f: in a narrow card the slots wrap, this many per row (88, gap 16); nil keeps one row.
    private let columns: Int?
    /// Board sizes on the screen's scale (88 circles on the 13"; six still fit the 11" row).
    @Environment(\.sizing) private var sizing
    private var d: CGFloat { sizing.pictureCircle(88) }

    public init(slots: [KitSlot], selection: Binding<KitSlot?>, all: [KitSlot], isShowingAll: Bool,
                moreTitle: String, columns: Int? = nil, onMore: @escaping () -> Void) {
        self.columns = columns
        self.slots = slots
        _selection = selection
        self.all = all
        self.isShowingAll = isShowingAll
        self.moreTitle = moreTitle
        self.onMore = onMore
    }

    public var body: some View {
        if let columns {
            // Layout v43: the rows spread edge to edge (the first slot on the left edge, the last on the right).
            LazyVGrid(columns: (0..<columns).map { column in
                GridItem(.flexible(minimum: d), spacing: Spacing.s,
                         alignment: column == 0 ? .leading : column == columns - 1 ? .trailing : .center)
            }, alignment: .leading, spacing: Spacing.s) { items }
        } else {
            HStack(spacing: Spacing.s) { items }
        }
    }

    @ViewBuilder private var items: some View {
            ForEach(Array(slots.enumerated()), id: \.element) { index, slot in
                let isOn = slot == selection
                Button { selection = slot } label: {
                    // Boards C3/C4: 88 paper circles with an ink outline; the picked one gets a 104
                    // blue ring around it.
                    KitIcon(slot, size: d * 64 / 88)
                        .frame(width: d, height: d)
                        .background(
                            CrayonSurface(.circle, fill: CrayonStyle.pictureGround, markerColor: CrayonColor.pictureOutline,
                                          seed: CrayonStyle.Seed.iconPicker + UInt32(index))
                                .padding(CrayonStyle.artInset)
                        )
                        .overlay {
                            if isOn {
                                CrayonSurface(.circle, fill: nil, markerColor: CrayonColor.link,
                                              seed: CrayonStyle.Seed.iconPicker + 500 + UInt32(index))
                                    .frame(width: d * 104 / 88, height: d * 104 / 88)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
            Button(action: onMore) {
                Text(moreTitle).crayonType(.caption, bold: true).foregroundStyle(CrayonColor.pictureInk)
                    .frame(width: d, height: d)
                    .background(CrayonSurface(.circle, fill: CrayonStyle.pictureGround, markerColor: CrayonColor.pictureOutline,
                                              seed: CrayonStyle.Seed.iconPicker + 998))
            }
            .buttonStyle(.plain)
            .overlay(alignment: .topTrailing) {
                if isShowingAll {
                    // Under the "More" slot, its right edge on the slot's: every picture, 6 per row.
                    PaperCard(seed: 97) { IconPicker(selection: $selection, slots: all) }
                        .fixedSize()
                        .offset(y: d + Spacing.sm)
                }
            }
    }
}
