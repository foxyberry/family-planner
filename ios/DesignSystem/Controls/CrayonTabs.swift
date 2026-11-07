import CrayonKit
import SwiftUI

/// Segmented tabs, 72 tall; only the selected one is sky blue. Items may carry a kid colour dot.
public struct CrayonTabs<ID: Hashable>: View {
    @Binding private var selection: ID
    private let items: [(ID, String, Color?)]

    public init(selection: Binding<ID>, items: [(ID, String, Color?)]) {
        _selection = selection
        self.items = items
    }

    public var body: some View {
        HStack(spacing: Spacing.s) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                let isOn = item.0 == selection
                Button { selection = item.0 } label: {
                    HStack(spacing: Spacing.xs) {
                        if let dot = item.2 { KidDot(color: dot) }
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
