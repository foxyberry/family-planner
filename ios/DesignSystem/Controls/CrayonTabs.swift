import CrayonKit
import SwiftUI

/// Segmented tabs, 72 tall; only the selected one is sky blue. Items may carry a kid's face (40,
/// beside the body 30 label).
public struct CrayonTabs<ID: Hashable>: View {
    @Environment(\.sizing) private var sizing
    @Binding private var selection: ID
    private let items: [(ID, String, KidFace.Badge?)]
    private let inset: CGFloat
    private let itemSize: CGSize?
    private let spacing: CGFloat
    private let faceOnly: Bool
    private let marked: Set<ID>
    private let widths: [CGFloat]?
    private let fills: Bool

    /// `compact`: 16 inside each tab instead of 24, so three short tabs fit the 382 side column (C6).
    /// `itemSize`: every tab the same size, `spacing` apart (S2 "Goes to" 180 × 72 gap 12; the MOE
    /// question's pills 140 × 64).
    /// `widths`: each tab its own width, 72 tall. `fills` (layout v42 fill rule): equal tabs alone on
    /// a row share its width, `spacing` apart. Sizes and `spacing` are board values (× s on screen).
    /// `faceOnly`: the kid's face without the name (S2/S3 with 3–4 kids, 88 × 72). `marked`: tabs that
    /// show a small hurry dot on the face (S3: route not finished).
    public init(selection: Binding<ID>, items: [(ID, String, KidFace.Badge?)], compact: Bool = false,
                itemSize: CGSize? = nil, widths: [CGFloat]? = nil, fills: Bool = false, spacing: CGFloat = Spacing.s,
                faceOnly: Bool = false, marked: Set<ID> = []) {
        self.widths = widths
        self.fills = fills
        self.faceOnly = faceOnly
        self.marked = marked
        _selection = selection
        self.items = items
        inset = compact ? Spacing.s : Spacing.m
        self.itemSize = itemSize
        self.spacing = spacing
    }

    public var body: some View {
        // A row of tabs that does not fit its column wraps (the same way at every s, since everything
        // scales together). Filling tabs share one row.
        let spacing = sizing(spacing)
        let row = fills ? AnyLayout(HStackLayout(spacing: spacing)) : AnyLayout(TabFlow(spacing: spacing))
        row {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                let isOn = item.0 == selection
                Button { selection = item.0 } label: {
                    HStack(spacing: sizing(KidFace.gap(for: KidFace.medium))) {
                        if let badge = item.2 {
                            KidFace(badge, size: sizing(KidFace.medium))
                                .overlay(alignment: .topTrailing) {
                                    if marked.contains(item.0) {
                                        Circle().fill(CrayonColor.hurry).frame(width: sizing(14), height: sizing(14))
                                            .offset(x: sizing(4), y: sizing(-4))
                                    }
                                }
                        }
                        // A tab label never wraps ("Mon–Fri" split over two lines on C6). In a tab of
                        // a fixed width a long typed name ends with "…" inside the capsule (spec
                        // "Sizing → Text that does not fit"); a hugging tab grows with its label.
                        if !faceOnly || item.2 == nil {
                            // Boards 0b/C1: the chosen label bold ink, the others regular soft text.
                            if width(at: index) != nil || fills {
                                Text(item.1).crayonType(.body, bold: isOn).lineLimit(1).truncationMode(.tail)
                            } else {
                                Text(item.1).crayonType(.body, bold: isOn).lineLimit(1).fixedSize()
                            }
                        }
                    }
                    .foregroundStyle(isOn ? CrayonColor.pictureInk : CrayonColor.softText)
                    // Text 24 from a hugging tab's edge (16 compact).
                    .padding(.horizontal, itemSize == nil && widths == nil && !fills ? sizing(inset) : 0)
                    .frame(width: width(at: index))
                    .frame(maxWidth: fills ? .infinity : nil)
                    // 72 × s (or `itemSize`'s height × s).
                    .frame(minHeight: sizing.tabHeight(baseHeight))
                    .partBackground(.capsule, fill: isOn ? CrayonStyle.skyPill : CrayonStyle.paper,
                                      seed: CrayonStyle.Seed.tabs + UInt32(index))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// A tab's fixed width × s: its own from `widths`, else `itemSize`'s; nil hugs the label.
    private func width(at index: Int) -> CGFloat? {
        if let widths, widths.indices.contains(index) { return sizing(widths[index]) }
        return itemSize.map { sizing($0.width) }
    }

    /// The tab height before `Sizing` scales it: `itemSize`'s, else the board's 72.
    private var baseHeight: CGFloat {
        if let itemSize { itemSize.height } else { 72 }
    }
}

/// Tabs left to right, `spacing` apart; a tab that would pass the proposed width starts a new row
/// (`spacing` below). Rows centre their tabs vertically.
struct TabFlow: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let available: CGFloat = if let width = proposal.width { width } else { .infinity }
        let rows = rows(width: available, subviews: subviews)
        let width: CGFloat = rows.map(\.width).reduce(0, max)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for (index, size) in zip(row.indices, row.sizes) {
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                                      proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var sizes: [CGSize] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let next = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if !row.indices.isEmpty, next > width + 0.5 {
                rows.append(row)
                row = Row()
            }
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.indices.append(index)
            row.sizes.append(size)
            row.height = max(row.height, size.height)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}
