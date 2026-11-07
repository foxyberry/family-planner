import SwiftUI

/// A plain row, 80 tall: a short leading label (a time) and content.
public struct ListRow<Content: View>: View {
    private let leading: String
    private let content: Content

    public init(leading: String, @ViewBuilder content: () -> Content) {
        self.leading = leading
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: Spacing.m) {
            Text(leading).crayonType(.caption).foregroundStyle(CrayonColor.softText).frame(width: 120, alignment: .leading)
            content.crayonType(.body).frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 80)
        .padding(.horizontal, Spacing.m)
    }
}

/// The row for today: a white paper card and bold text.
public struct TodayRow<Content: View>: View {
    private let leading: String
    private let content: Content

    public init(leading: String, @ViewBuilder content: () -> Content) {
        self.leading = leading
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: Spacing.m) {
            Text(leading).crayonType(.caption).bold().frame(width: 120, alignment: .leading)
            content.crayonType(.head).frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(CrayonColor.ink)
        .frame(minHeight: 80)
        .padding(.horizontal, Spacing.m)
        .crayonBackground(.roundedRect(cornerRadius: 24), fill: CrayonStyle.paper, seed: CrayonStyle.Seed.card + 50)
    }
}
