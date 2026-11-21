import CrayonKit
import SwiftUI

/// A plain row, 80 tall: a short leading label (a time) and content. In a grown-up form the label
/// fills the label column (`formLabelWidth`) and the content starts on the control line.
public struct ListRow<Content: View>: View {
    private let leading: String
    private let minHeight: CGFloat?
    private let labelHeight: CGFloat?
    private let content: Content
    @Environment(\.formLabelWidth) private var formLabelWidth
    @Environment(\.sizing) private var sizing

    /// `minHeight` (screen points): nil is the field row, 80 × s; 60 × s for the read-only rows of
    /// C1/E6.
    /// `labelHeight`: top-align the row and centre the label on the control's first line of that
    /// height (C2 "Stop": the 80 field, not the field plus its caption).
    public init(leading: String, minHeight: CGFloat? = nil, labelHeight: CGFloat? = nil,
                @ViewBuilder content: () -> Content) {
        self.leading = leading
        self.minHeight = minHeight
        self.labelHeight = labelHeight
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: labelHeight == nil ? .center : .top, spacing: formLabelWidth == nil ? sizing(Spacing.m) : 0) {
            // Boards C1–C4: row labels are caption bold in soft text, one line; the card's label
            // column fits its longest label (spec "Label column").
            Text(leading).crayonType(.caption, bold: true).foregroundStyle(CrayonColor.softText)
                .lineLimit(1)
                .frame(width: labelWidth, height: labelHeight, alignment: .leading)
            content.crayonType(.body).frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: rowHeight)
        .padding(.horizontal, formLabelWidth == nil ? sizing(Spacing.m) : 0)
    }

    private var rowHeight: CGFloat {
        if let minHeight { minHeight } else { sizing.fieldHeight }
    }

    /// The form's label column; outside a grown-up form, 120 × s.
    private var labelWidth: CGFloat {
        if let formLabelWidth { formLabelWidth } else { sizing(120) }
    }
}

/// The row for today: a white paper card and bold text.
public struct TodayRow<Content: View>: View {
    private let leading: String
    private let content: Content
    @Environment(\.sizing) private var sizing

    public init(leading: String, @ViewBuilder content: () -> Content) {
        self.leading = leading
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: sizing(Spacing.m)) {
            Text(leading).crayonType(.caption).bold().frame(width: sizing(120), alignment: .leading)
            content.crayonType(.head).frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(CrayonColor.ink)
        .frame(minHeight: sizing(80))
        .padding(.horizontal, sizing(Spacing.m))
        .partBackground(.roundedRect(cornerRadius: 24), fill: CrayonStyle.paper, seed: CrayonStyle.Seed.card + 50)
    }
}

/// A row of a day preview (boards C3/C4 side column): 72 tall, the time (caption, ink) 24 in, then
/// the content 116 after it. `isNew` (the item being added) sits on a white paper card in bold.
public struct PreviewRow<Content: View>: View {
    public static var timeColumn: CGFloat { 116 }
    private let time: String
    private let isNew: Bool
    private let content: Content
    @Environment(\.sizing) private var sizing

    public init(time: String, isNew: Bool, @ViewBuilder content: () -> Content) {
        self.time = time
        self.isNew = isNew
        self.content = content()
    }

    public var body: some View {
        HStack(spacing: 0) {
            // The time column is 116 × s (the widest time "10:00 am" is 115.5 on the board); a time
            // never gets "…", only a typed title may. It is never squeezed (spec "Sizing → Text").
            // The new row's bold time may need a few points more: the column grows, never the text
            // shrinks.
            Text(time).crayonType(.caption, bold: isNew).lineLimit(1).fixedSize()
                .frame(minWidth: sizing(Self.timeColumn), alignment: .leading)
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(CrayonColor.ink)
        .padding(.leading, sizing(Spacing.m))
        .frame(height: sizing(72))
        .background {
            if isNew {
                CrayonSurface(.roundedRect(cornerRadius: 24), fill: CrayonStyle.paper, seed: CrayonStyle.Seed.card + 50)
                    .padding(sizing(CrayonStyle.artInset))
            }
        }
    }
}

/// A grown-up form's row label (body, `softText`): it fills the label column, so the control after
/// it starts on 232 (`formLabelWidth`); outside a grown-up form it is 120 wide plus a 24 gap.
public struct FormLabel: View {
    private let text: String
    private let isActive: Bool

    /// `isActive`: the row's field has focus (board C3k); the label turns `pickBlue`.
    public init(_ text: String, isActive: Bool = false) {
        self.text = text
        self.isActive = isActive
    }

    public var body: some View {
        FormLabelColumn {
            Text(text).crayonType(.caption, bold: true)
                .foregroundStyle(isActive ? CrayonColor.pickBlue : CrayonColor.softText)
                .lineLimit(1)
        }
    }
}

/// The label column (104 … 232) holding something other than words, such as C4's "earlier dates" ‹.
public struct FormLabelColumn<Content: View>: View {
    private let content: Content
    @Environment(\.formLabelWidth) private var formLabelWidth
    @Environment(\.sizing) private var sizing

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content.frame(width: columnWidth, alignment: .leading)
    }

    /// The form's label column; outside a grown-up form, 120 plus the 24 gap, × s.
    private var columnWidth: CGFloat {
        if let formLabelWidth { formLabelWidth } else { sizing(120 + Spacing.m) }
    }
}
