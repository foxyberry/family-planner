import CrayonKit
import SwiftUI

/// Segmented tabs, 72 tall; only the selected one is sky blue. Items may carry a kid's face (40,
/// beside the body 30 label).
public struct CrayonTabs<ID: Hashable>: View {
    @Binding private var selection: ID
    private let items: [(ID, String, KidFace.Badge?)]

    public init(selection: Binding<ID>, items: [(ID, String, KidFace.Badge?)]) {
        _selection = selection
        self.items = items
    }

    public var body: some View {
        HStack(spacing: Spacing.s) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                let isOn = item.0 == selection
                Button { selection = item.0 } label: {
                    HStack(spacing: KidFace.gap(for: KidFace.medium)) {
                        if let badge = item.2 {
                            KidFace(badge, name: item.1, size: KidFace.medium).accessibilityHidden(true)
                        }
                        Text(item.1).crayonType(.body)
                    }
                    .foregroundStyle(CrayonColor.ink)
                    .padding(.horizontal, Spacing.m)
                    .frame(minHeight: 72)
                    .crayonBackground(.capsule, fill: isOn ? CrayonStyle.skyPill : CrayonStyle.paper,
                                      seed: CrayonStyle.Seed.tabs + UInt32(index))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}
