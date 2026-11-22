import CrayonKit
import SwiftUI

/// Spec C2 "Result list card", shared by the stop and school searches: an opaque white
/// card as wide as the control column (610 by default; 592 on the v31 grown-up form, 208–800), 12 padding top and bottom, rows 72 tall with the
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

    /// Board values (× s on screen).
    public static let rowHeight: CGFloat = 72
    /// S2s with the keyboard up (design session 2026-11-15): one line, "{name} · {caption}".
    public static let compactRowHeight: CGFloat = 48
    private static let padding: CGFloat = 12

    private let rows: [Row]
    private let visibleRows: Int
    private let seed: UInt32
    private let width: CGFloat
    /// Keyboard up: one-line rows in a card exactly `fitHeight` tall, down to the keyboard, so a cut
    /// row at the foot shows there is more to scroll.
    private let fitHeight: CGFloat?

    /// `width` and `fitHeight` in screen points.
    public init(rows: [Row], visibleRows: Int, seed: UInt32, width: CGFloat, fitHeight: CGFloat? = nil) {
        self.rows = rows
        self.visibleRows = max(visibleRows, 1)
        self.seed = seed
        self.width = width
        self.fitHeight = fitHeight
    }

    @Environment(\.sizing) private var sizing
    private var cardWidth: CGFloat { width }
    private var isCompact: Bool { fitHeight != nil }
    /// One-line rows 48 × s; two-line rows 72 × s.
    private var rowHeight: CGFloat { isCompact ? sizing.oneLineRow : sizing.twoLineRow }
    private var padding: CGFloat { sizing(isCompact ? Spacing.xs : Self.padding) }

    /// The card's height for `count` rows when `visible` fit, on `sizing`.
    public static func height(rows count: Int, visible: Int, sizing: Sizing) -> CGFloat {
        let shown = min(count, max(visible, 1))
        return sizing(CGFloat(shown) * rowHeight + CGFloat(max(shown - 1, 0)) * 2 + 2 * padding)
    }

    public var body: some View {
        // Every row's height; the card shows `visibleRows` (or `fitHeight`) of it and scrolls the rest.
        let full = isCompact ? CGFloat(rows.count) * (rowHeight + sizing(2)) - sizing(2) + 2 * padding
            : Self.height(rows: rows.count, visible: rows.count, sizing: sizing)
        let height = if let fitHeight { min(fitHeight, full) } else {
            Self.height(rows: rows.count, visible: visibleRows, sizing: sizing)
        }
        Group {
            if height < full {
                ScrollView(.vertical) { list }.scrollIndicators(.visible)
            } else {
                list
            }
        }
        .padding(.vertical, padding)
        .frame(width: cardWidth, height: height, alignment: .top)
        .partBackground(.roundedRect(cornerRadius: 24), fill: CrayonStyle.paper,
                          seed: CrayonStyle.Seed.card + seed, tap: .frame)
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                // Layout v21: no lines inside cards; rows keep the 2 gap as space.
                if index > 0 { Color.clear.frame(height: sizing(2)) }
                Button(action: row.action) { label(row) }
                    .buttonStyle(.plain)
            }
        }
    }

    private func label(_ row: Row) -> some View {
        HStack(spacing: sizing(Spacing.sm)) {
            if let glyph = row.glyph { MarkerIcon(glyph, size: sizing(32), color: CrayonColor.link) }
            if isCompact {
                // One line: the name, then " · {caption}" in soft text.
                HStack(spacing: 0) {
                    Text(row.title).crayonType(.body, bold: true).foregroundStyle(CrayonColor.link)
                        .lineLimit(1).layoutPriority(1)
                    if let caption = row.caption {
                        Text(" · " + caption).crayonType(.caption).foregroundStyle(CrayonColor.softText) // copy-ok: a separator
                            .lineLimit(1).truncationMode(.tail)
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: sizing(2)) {
                    Text(row.title).crayonType(.body, bold: true).foregroundStyle(CrayonColor.link)
                        .lineLimit(1).truncationMode(.tail)
                    if let caption = row.caption {
                        Text(caption).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                            .lineLimit(1).truncationMode(.tail)
                    }
                }
            }
        }
        .padding(.horizontal, sizing(Spacing.m))
        .frame(width: cardWidth, height: rowHeight, alignment: .leading)
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
    /// Keeps this view clear of the screen's result-list veil. It adds to the holes inside it: a plain
    /// `anchorPreference` would replace them, which veiled the open card under a marked field.
    public func resultVeilHole() -> some View {
        transformAnchorPreference(key: ResultVeilHoles.self, value: .bounds) { $0.append($1) }
    }

    /// Spec "Result list card": while a list is open, paper at 72 % veils the screen except the
    /// views marked `resultVeilHole()`. No tap goes through the veil; a tap on it closes the list.
    public func resultVeil(isOpen: Bool, onClose: @escaping () -> Void) -> some View {
        modifier(ResultVeil(isOpen: isOpen, onClose: onClose))
    }
}

private struct ResultVeil: ViewModifier {
    let isOpen: Bool
    let onClose: () -> Void
    @Environment(\.sizing) private var sizing

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(ResultVeilHoles.self) { anchors in
            if isOpen {
                GeometryReader { proxy in
                    let holes = anchors.map { proxy[$0] }
                    let veil = VeilShape(holes: holes, margin: sizing(8), corner: sizing(24))
                    veil.fill(CrayonColor.paper.opacity(0.72), style: FillStyle(eoFill: true))
                        .contentShape(veil, eoFill: true)
                        .onTapGesture(perform: onClose)
                }
                .fullBleed()
            }
        }
    }
}

/// The whole screen with the marked views cut out, `margin` around each.
private struct VeilShape: Shape {
    let holes: [CGRect]
    let margin: CGFloat
    let corner: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path(rect.insetBy(dx: -200, dy: -200))
        for hole in Self.merged(holes.map { $0.insetBy(dx: -margin, dy: -margin) }) {
            path.addRoundedRect(in: hole, cornerSize: CGSize(width: corner, height: corner))
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
