import CrayonKit
import KitArt
import SwiftUI

/// Board C3 "What": one row of picture slots (88, gap 16; the picked one has a blue
/// ring), then a "More" slot (88 circle, bold caption). "More" opens a card under the row with every
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
            // Layout v43: the rows spread edge to edge (the first slot on the left edge, the last on the right).
            LazyVGrid(columns: (0..<columns).map { column in
                GridItem(.flexible(minimum: d), spacing: sizing(Spacing.s),
                         alignment: column == 0 ? .leading : column == columns - 1 ? .trailing : .center)
            }, alignment: .leading, spacing: sizing(Spacing.s)) { items }
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
                if isShowingAll {
                    // Under the "More" slot, its right edge on the slot's: every picture, 6 per row,
                    // then the flags from a new row (the rows' own 16 apart). In a narrow card (G1f)
                    // it shows 3 per row and scrolls inside, so with its own padding it stays inside
                    // the side column and above the action button; two rows and a peek of the third
                    // show, so more is visibly there.
                    PaperCard(seed: 97) {
                        if columns != nil {
                            // The pick ring draws a little outside a slot, so the list keeps a margin.
                            ScrollView { morePictures(columns: Self.narrowMoreColumns).padding(sizing(Spacing.xs)) }
                                .scrollIndicators(.hidden)
                                .frame(width: sizing(CGFloat(Self.narrowMoreColumns) * 88
                                                     + CGFloat(Self.narrowMoreColumns - 1) * Spacing.s + 2 * Spacing.xs),
                                       height: sizing(Self.narrowMoreHeight))
                        } else {
                            morePictures(columns: IconPicker.columns)
                        }
                    }
                    .fixedSize()
                    .offset(y: d + sizing(Spacing.sm))
                }
            }
    }

    /// Board units: a narrow card's More list shows two rows of 88 slots (16 apart) and a peek of the
    /// third, inside the list's margin.
    static let narrowMoreHeight: CGFloat = 2 * (88 + Spacing.s) + 28 + 2 * Spacing.xs
    /// A narrow card's More list: 3 per row (`IconPicker`'s side-column count).
    static let narrowMoreColumns = 3

    private func morePictures(columns: Int) -> some View {
        VStack(alignment: .leading, spacing: sizing(Spacing.s)) {
            IconPicker(selection: $selection, slots: all, columns: columns)
            if !flags.isEmpty { IconPicker(selection: $selection, slots: flags, columns: columns) }
        }
    }
}
