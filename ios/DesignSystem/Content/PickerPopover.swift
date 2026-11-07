import CrayonKit
import SwiftUI

/// A small choice bubble whose tail points at the field that opened it. One item is always
/// selected (there is a default).
public struct PickerPopover<Item: Hashable & CustomStringConvertible>: View {
    private let title: String
    private let items: [Item]
    @Binding private var selection: Item
    private let anchor: CGFloat

    /// `anchor` is where the tail sits along the bottom edge, 0...1.
    public init(title: String, items: [Item], selection: Binding<Item>, anchor: CGFloat) {
        self.title = title
        self.items = items
        _selection = selection
        self.anchor = anchor
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(title).crayonType(.caption).foregroundStyle(CrayonColor.softText)
            ForEach(items, id: \.self) { item in
                Button { selection = item } label: {
                    HStack {
                        Text(item.description).crayonType(.body)
                        Spacer()
                        if item == selection { CheckMark(isDone: true, size: 40) }
                    }
                    .foregroundStyle(CrayonColor.ink)
                    .frame(minHeight: 64)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(item == selection ? .isSelected : [])
            }
        }
        .padding(Spacing.m)
        .padding(.bottom, 24)
        .crayonBackground(.speechBubble(tailX: anchor, tailHeight: 24), fill: CrayonStyle.paper,
                          seed: CrayonStyle.Seed.bubble + 7)
    }
}
