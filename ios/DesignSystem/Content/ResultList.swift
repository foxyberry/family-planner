import CrayonKit
import SwiftUI

/// Spec C2 "Result list card" (layout v14), shared by the stop and school searches: an opaque white
/// card 610 wide (the control column 232–842), 12 padding top and bottom, rows 72 tall with the
/// name (body bold, link, one line) over its caption, 2 apart with no line (layout v21). Past
/// `visibleRows` the rows scroll inside the card.
///
/// It sits in a field's overlay, which proposes the field's own size, so the card fixes its own
/// width and height instead of taking the proposal (that squeezed the rows on top of each other).
public struct ResultListCard: View {
    public struct Row: Identifiable {
        public let id: String
        let title: String
        let caption: String?
        let glyph: MarkerGlyph?
        let action: () -> Void

        /// A result: its name over a caption ("Orchard Blvd · 09111").
        public init(id: String, title: String, caption: String?, action: @escaping () -> Void) {
            self.id = id
            self.title = title
            self.caption = caption
            glyph = nil
            self.action = action
        }

        /// A last row such as "+ Not in the list? Type the name".
        public init(id: String, glyph: MarkerGlyph, title: String, action: @escaping () -> Void) {
            self.id = id
            self.title = title
            caption = nil
            self.glyph = glyph
            self.action = action
        }
    }

    public static let width: CGFloat = 610
    public static let rowHeight: CGFloat = 72
    private static let padding: CGFloat = 12

    private let rows: [Row]
    private let visibleRows: Int
    private let seed: UInt32

    public init(rows: [Row], visibleRows: Int, seed: UInt32) {
        self.rows = rows
        self.visibleRows = max(visibleRows, 1)
        self.seed = seed
    }

    /// The card's height for `count` rows when `visible` fit.
    public static func height(rows count: Int, visible: Int) -> CGFloat {
        let shown = min(count, max(visible, 1))
        return CGFloat(shown) * rowHeight + CGFloat(max(shown - 1, 0)) * 2 + 2 * padding
    }

    public var body: some View {
        let height = Self.height(rows: rows.count, visible: visibleRows)
        Group {
            if rows.count > visibleRows {
                ScrollView(.vertical) { list }.scrollIndicators(.visible)
            } else {
                list
            }
        }
        .padding(.vertical, Self.padding)
        .frame(width: Self.width, height: height, alignment: .top)
        .partBackground(.roundedRect(cornerRadius: 24), fill: CrayonStyle.paper,
                          seed: CrayonStyle.Seed.card + seed)
        .contentShape(Rectangle())
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                // Layout v21: no lines inside cards; rows keep the 2 gap as space.
                if index > 0 { Color.clear.frame(height: 2) }
                Button(action: row.action) { label(row) }
                    .buttonStyle(.plain)
            }
        }
    }

    private func label(_ row: Row) -> some View {
        HStack(spacing: Spacing.sm) {
            if let glyph = row.glyph { MarkerIcon(glyph, size: 32, color: CrayonColor.link) }
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title).crayonType(.body, bold: true).foregroundStyle(CrayonColor.link)
                    .lineLimit(1).truncationMode(.tail)
                if let caption = row.caption {
                    Text(caption).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                        .lineLimit(1).truncationMode(.tail)
                }
            }
        }
        .padding(.horizontal, Spacing.m)
        .frame(width: Self.width, height: Self.rowHeight, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: The veil

/// Marks the field, its caption and the open card: `resultVeil` leaves these clear.
private struct ResultVeilHoles: PreferenceKey {
    static let defaultValue: [Anchor<CGRect>] = []
    static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) {
        value.append(contentsOf: nextValue())
    }
}

extension View {
    /// Keeps this view clear of the screen's result-list veil.
    public func resultVeilHole() -> some View {
        anchorPreference(key: ResultVeilHoles.self, value: .bounds) { [$0] }
    }

    /// Spec "Result list card": while a list is open, paper at 72 % veils the screen except the
    /// views marked `resultVeilHole()`. No tap goes through the veil; a tap on it closes the list.
    public func resultVeil(isOpen: Bool, onClose: @escaping () -> Void) -> some View {
        overlayPreferenceValue(ResultVeilHoles.self) { anchors in
            if isOpen {
                GeometryReader { proxy in
                    let holes = anchors.map { proxy[$0] }
                    let veil = VeilShape(holes: holes)
                    veil.fill(CrayonColor.paper.opacity(0.72), style: FillStyle(eoFill: true))
                        .contentShape(veil, eoFill: true)
                        .onTapGesture(perform: onClose)
                }
                .ignoresSafeArea()
                .accessibilityHidden(true)
            }
        }
    }
}

/// The whole screen with the marked views cut out.
private struct VeilShape: Shape {
    let holes: [CGRect]

    func path(in rect: CGRect) -> Path {
        var path = Path(rect.insetBy(dx: -200, dy: -200))
        for hole in Self.merged(holes.map { $0.insetBy(dx: -8, dy: -8) }) {
            path.addRoundedRect(in: hole, cornerSize: CGSize(width: 24, height: 24))
        }
        return path
    }

    /// Overlapping holes become one: with the even-odd fill an overlap would be veiled again.
    static func merged(_ rects: [CGRect]) -> [CGRect] {
        var result: [CGRect] = []
        for rect in rects {
            var joined = rect
            while let index = result.firstIndex(where: { $0.intersects(joined) }) {
                joined = joined.union(result.remove(at: index))
            }
            result.append(joined)
        }
        return result
    }
}
