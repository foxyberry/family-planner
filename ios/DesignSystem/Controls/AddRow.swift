import CrayonKit
import SwiftUI

/// An "add" row (board C5: "+ Add a mission", "New bundle"): a `plus` in a 56 crayon ring, then its
/// words in body `link`; 72 tall.
public struct AddRow: View {
    private let title: String
    private let seed: UInt32
    private let action: () -> Void
    @Environment(\.sizing) private var sizing

    public init(_ title: String, seed: UInt32 = 1801, action: @escaping () -> Void) {
        self.title = title
        self.seed = seed
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: sizing(Spacing.s)) {
                MarkerIcon(.plus, size: sizing(28), color: CrayonColor.link)
                    .frame(width: sizing(56), height: sizing(56))
                    .crayonBackground(.circle, fill: nil, seed: seed)
                Text(title).crayonType(.body).foregroundStyle(CrayonColor.link)
            }
            .frame(height: sizing(72))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
