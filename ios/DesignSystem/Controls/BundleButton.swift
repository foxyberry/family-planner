import CrayonKit
import SwiftUI

/// One bundle in C5's side column (board C5, layout v77, issue 024): as wide as the column, 88 tall,
/// its name in body; the picked one on the sky hatch with a bold name, the others on paper.
public struct BundleButton: View {
    public static let height: CGFloat = 88
    private let title: String
    private let isPicked: Bool
    private let action: () -> Void
    @Environment(\.sizing) private var sizing

    public init(_ title: String, isPicked: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isPicked = isPicked
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title).crayonType(.body, bold: isPicked).foregroundStyle(CrayonColor.ink).lineLimit(1)
                .padding(.horizontal, sizing(Spacing.m))
                .frame(maxWidth: .infinity, minHeight: sizing(Self.height), alignment: .leading)
                .partBackground(.roundedRect(cornerRadius: 26), fill: isPicked ? CrayonStyle.skyPill : CrayonStyle.paper,
                                seed: CrayonStyle.Seed.removeButton + (isPicked ? 1 : 2))
        }
        .buttonStyle(.plain)
    }
}
