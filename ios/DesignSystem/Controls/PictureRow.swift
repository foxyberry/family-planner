import CrayonKit
import KitArt
import SwiftUI

/// Board C3 "What": one row of picture slots (88, gap 16; the picked one has a blue
/// ring), then a "More" slot (88 circle, bold caption); in G1f's narrow card the slots wrap, 4 per
/// row and 24 apart. "More" opens a card under the row with every
/// picture, 6 per row (`IconPicker`), and after them, starting on a row of their own, the country
/// flags (spec C3 "What", N15); the row never wraps or scrolls, so the rows below keep their lines.
/// Callers pass the slots (the picked one first), the lists and the words.
public struct PictureRow: View {
    private let slots: [KitSlot]
    @Binding private var selection: KitSlot?
    private let all: [KitSlot]
    /// The second group in the "More" card (the country flags), on rows of its own.
    private let flags: [KitSlot]
    private let isShowingAll: Bool
    private let moreTitle: String
    private let onMore: () -> Void
    /// Board G1f: in a narrow card the slots wrap, this many per row (88, gap 16); nil keeps one row.
    private let columns: Int?
    /// Board sizes × s (88 circles).
    @Environment(\.sizing) private var sizing
    private var d: CGFloat { sizing(88) }

    public init(slots: [KitSlot], selection: Binding<KitSlot?>, all: [KitSlot], flags: [KitSlot] = [],
                isShowingAll: Bool, moreTitle: String, columns: Int? = nil, onMore: @escaping () -> Void) {
        self.columns = columns
        self.slots = slots
        _selection = selection
        self.all = all
        self.flags = flags
        self.isShowingAll = isShowingAll
        self.moreTitle = moreTitle
        self.onMore = onMore
    }

    public var body: some View {
        if let columns {
            // Spec G1f: 88 slots spread edge to edge across the 424 card, 24 apart (4 × 88 + 3 × 24),
            // rows 16 apart.
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(d), spacing: sizing(Self.narrowColumnGap)), count: columns),
                      alignment: .leading, spacing: sizing(Spacing.s)) { items }
                // Spec G1f "More": the card spans the side column (the grid ± its 24 inset), its top 8
                // under the "More" slot in the last row; it covers the rows below while open.
                .overlay(alignment: .top) {
                    if isShowingAll {
                        narrowMoreCard(columns: columns)
                            .offset(y: sizing(Self.gridHeight(slots: slots.count + 1, columns: columns) + Self.narrowMoreTop))
                    }
                }
        } else {
            HStack(spacing: sizing(Spacing.s)) { items }
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
                                .padding(sizing(CrayonStyle.artInset))
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
                if isShowingAll && columns == nil {
                    // Under the "More" slot, its right edge on the slot's: every picture, 6 per row,
                    // then the flags from a new row (the rows' own 16 apart).
                    PaperCard(seed: 97) { morePictures(columns: IconPicker.columns, gap: Spacing.s) }
                        .fixedSize()
                        .offset(y: d + sizing(Spacing.sm))
                }
            }
    }

    /// Spec G1f: the board gap between the 4 slots across the 424 card.
    static let narrowColumnGap: CGFloat = 24
    /// Spec G1f "More": the card's top 8 under the "More" slot, its size 472 × 300 with a 24 inset,
    /// and a scroll area 424 × 252: two rows (88 + 16 + 88), 16, then 44 of the third as a peek.
    static let narrowMoreTop: CGFloat = 8
    static let narrowMoreCard = CGSize(width: 472, height: 300)
    static let narrowMoreList = CGSize(width: 424, height: 252)

    /// The narrow grid's board height: rows of 88, 16 apart.
    static func gridHeight(slots: Int, columns: Int) -> CGFloat {
        let rows = (slots + columns - 1) / max(columns, 1)
        return CGFloat(rows) * 88 + CGFloat(max(rows - 1, 0)) * Spacing.s
    }

    /// Spec G1f "More": every picture and then the flags, 4 per row like the grid, scrolling inside.
    private func narrowMoreCard(columns: Int) -> some View {
        ScrollView { morePictures(columns: columns, gap: Self.narrowColumnGap) }
            .scrollIndicators(.hidden)
            .frame(width: sizing(Self.narrowMoreList.width), height: sizing(Self.narrowMoreList.height), alignment: .top)
            .frame(width: sizing(Self.narrowMoreCard.width), height: sizing(Self.narrowMoreCard.height))
            .background(PaperCard(seed: 97) { Color.clear })
    }

    private func morePictures(columns: Int, gap: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: sizing(Spacing.s)) {
            IconPicker(selection: $selection, slots: all, columns: columns).columnGap(gap)
            if !flags.isEmpty { IconPicker(selection: $selection, slots: flags, columns: columns).columnGap(gap) }
        }
    }
}
