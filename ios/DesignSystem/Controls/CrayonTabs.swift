import CrayonKit
import SwiftUI

/// Segmented tabs, 72 tall; only the selected one is sky blue. Items may carry a kid's face (40,
/// beside the body 30 label).
public struct CrayonTabs<ID: Hashable>: View {
    @Binding private var selection: ID
    private let items: [(ID, String, KidFace.Badge?)]
    private let inset: CGFloat
    private let itemSize: CGSize?
    private let spacing: CGFloat

    /// `compact`: 16 inside each tab instead of 24, so three short tabs fit the 382 side column (C6).
    /// `itemSize`: every tab the same size, `spacing` apart (S2 "Goes to" 180 × 72 gap 12; the MOE
    /// question's pills 140 × 64).
    public init(selection: Binding<ID>, items: [(ID, String, KidFace.Badge?)], compact: Bool = false,
                itemSize: CGSize? = nil, spacing: CGFloat = Spacing.s) {
        _selection = selection
        self.items = items
        inset = compact ? Spacing.s : Spacing.m
        self.itemSize = itemSize
        self.spacing = spacing
    }

    public var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                let isOn = item.0 == selection
                Button { selection = item.0 } label: {
                    HStack(spacing: KidFace.gap(for: KidFace.medium)) {
                        if let badge = item.2 {
                            KidFace(badge, name: item.1, size: KidFace.medium).accessibilityHidden(true)
                        }
                        // A tab label never wraps ("Mon–Fri" split over two lines on C6).
                        Text(item.1).crayonType(.body).lineLimit(1).fixedSize()
                    }
                    .foregroundStyle(CrayonColor.ink)
                    .padding(.horizontal, itemSize == nil ? inset : 0)
                    .frame(width: itemSize?.width)
                    .frame(minHeight: itemSize?.height ?? 72)
                    .crayonBackground(.capsule, fill: isOn ? CrayonStyle.skyPill : CrayonStyle.paper,
                                      seed: CrayonStyle.Seed.tabs + UInt32(index))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}
