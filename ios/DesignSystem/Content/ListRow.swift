import SwiftUI

/// A plain row, 80 tall: a short leading label (a time) and content. In a grown-up form the label
/// fills the label column (`formLabelWidth`) and the content starts on the control line.
public struct ListRow<Content: View>: View {
    private let leading: String
    private let content: Content
    @Environment(\.formLabelWidth) private var formLabelWidth

    public init(leading: String, @ViewBuilder content: () -> Content) {
        self.leading = leading
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: formLabelWidth == nil ? Spacing.m : 0) {
            // Boards C1–C4: row labels are caption bold in soft text.
            Text(leading).crayonType(.caption, bold: true).foregroundStyle(CrayonColor.softText)
                .frame(width: formLabelWidth ?? 120, alignment: .leading)
            content.crayonType(.body).frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 80)
        .padding(.horizontal, formLabelWidth == nil ? Spacing.m : 0)
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

/// A grown-up form's row label (body, `softText`): it fills the label column, so the control after
/// it starts on 232 (`formLabelWidth`); outside a grown-up form it is 120 wide plus a 24 gap.
public struct FormLabel: View {
    private let text: String

    public init(_ text: String) {
        self.text = text
    }

    public var body: some View {
        FormLabelColumn { Text(text).crayonType(.caption, bold: true).foregroundStyle(CrayonColor.softText) }
    }
}

/// The label column (104 … 232) holding something other than words, such as C4's "earlier dates" ‹.
public struct FormLabelColumn<Content: View>: View {
    private let content: Content
    @Environment(\.formLabelWidth) private var formLabelWidth

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content.frame(width: formLabelWidth ?? 120 + Spacing.m, alignment: .leading)
    }
}
