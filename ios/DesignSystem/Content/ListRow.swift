import CrayonKit
import SwiftUI

/// A plain row, 80 tall: a short leading label (a time) and content. In a grown-up form the label
/// fills the label column (`formLabelWidth`) and the content starts on the control line.
public struct ListRow<Content: View>: View {
    private let leading: String
    private let minHeight: CGFloat
    private let labelHeight: CGFloat?
    private let content: Content
    @Environment(\.formLabelWidth) private var formLabelWidth

    /// `minHeight`: 80 for form rows; 60 for the read-only rows of C1/E6.
    /// `labelHeight`: top-align the row and centre the label on the control's first line of that
    /// height (C2 "Stop": the 80 field, not the field plus its caption).
    public init(leading: String, minHeight: CGFloat = 80, labelHeight: CGFloat? = nil,
                @ViewBuilder content: () -> Content) {
        self.leading = leading
        self.minHeight = minHeight
        self.labelHeight = labelHeight
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: labelHeight == nil ? .center : .top, spacing: formLabelWidth == nil ? Spacing.m : 0) {
            // Boards C1–C4: row labels are caption bold in soft text.
            Text(leading).crayonType(.caption, bold: true).foregroundStyle(CrayonColor.softText)
                .frame(width: formLabelWidth ?? 120, height: labelHeight, alignment: .leading)
            content.crayonType(.body).frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: minHeight)
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
        .partBackground(.roundedRect(cornerRadius: 24), fill: CrayonStyle.paper, seed: CrayonStyle.Seed.card + 50)
    }
}

/// A row of a day preview (boards C3/C4 side column): 72 tall, the time (caption, ink) 24 in, then
/// the content 112 after it. `isNew` (the item being added) sits on a white paper card in bold.
public struct PreviewRow<Content: View>: View {
    private let time: String
    private let isNew: Bool
    private let content: Content

    public init(time: String, isNew: Bool, @ViewBuilder content: () -> Content) {
        self.time = time
        self.isNew = isNew
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Boards C3/C4: the time column is 112 (888 … 1000); the new row's bold time shrinks to fit.
            Text(time).crayonType(.caption, bold: isNew).lineLimit(1).minimumScaleFactor(0.8)
                .frame(width: 112, alignment: .leading)
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(CrayonColor.ink)
        .padding(.leading, Spacing.m)
        .frame(height: 72)
        .background {
            if isNew {
                CrayonSurface(.roundedRect(cornerRadius: 24), fill: CrayonStyle.paper, seed: CrayonStyle.Seed.card + 50)
                    .padding(CrayonStyle.artInset)
            }
        }
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
