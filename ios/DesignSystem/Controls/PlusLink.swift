import CrayonKit
import SwiftUI

/// A link that adds something under a form's rows (boards C2 and S3 "+ A bus that changes…"): the
/// drawn "+" 28 and the words body bold in `link`, 72 tall to touch.
public struct PlusLink: View {
    public static let height: CGFloat = 72
    private let title: String
    private let action: () -> Void
    @Environment(\.sizing) private var sizing

    public init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: sizing(Spacing.s)) {
                MarkerIcon(.plus, size: sizing(28), color: CrayonColor.ink)
                Text(title).crayonType(.body, bold: true).foregroundStyle(CrayonColor.link)
            }
            .frame(minHeight: sizing(Self.height))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
