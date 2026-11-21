import CrayonKit
import SwiftUI

/// The side column's remove button (board G2 "Remove every week", C2c "Remove this bus", layout
/// v61): as wide as the column, 88 tall, its words head bold in `lateText` on paper. It opens the
/// shared `ConfirmCard`; it never removes on its own.
public struct RemoveButton: View {
    public static let height: CGFloat = 88
    private let title: String
    private let action: () -> Void
    @Environment(\.sizing) private var sizing

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title).crayonType(.head).foregroundStyle(CrayonColor.lateText)
                .frame(maxWidth: .infinity, minHeight: sizing(Self.height))
                .partBackground(.roundedRect(cornerRadius: 26), fill: CrayonStyle.paper, seed: CrayonStyle.Seed.removeButton)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
