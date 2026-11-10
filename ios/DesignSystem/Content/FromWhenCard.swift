import CrayonKit
import SwiftUI

/// Board G5 "Change from when?": Today / Next {weekday} / Date tabs, a date field for Date, an
/// optional caption (days that no longer fit), then Save and Cancel. Used by every All days save.
public struct FromWhenCard<Choice: Hashable>: View {
    private let title: String
    private let tabs: [(Choice, String)]
    @Binding private var selection: Choice
    private let dateChoice: Choice
    private let dateLabel: String
    @Binding private var date: Date
    private let caption: String?
    private let save: String
    private let cancel: String
    private let onSave: () -> Void
    private let onCancel: () -> Void

    public init(title: String, tabs: [(Choice, String)], selection: Binding<Choice>, dateChoice: Choice,
                dateLabel: String, date: Binding<Date>, caption: String?, save: String, cancel: String,
                onSave: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.title = title
        self.tabs = tabs
        _selection = selection
        self.dateChoice = dateChoice
        self.dateLabel = dateLabel
        _date = date
        self.caption = caption
        self.save = save
        self.cancel = cancel
        self.onSave = onSave
        self.onCancel = onCancel
    }

    public var body: some View {
        PaperCard(seed: 51) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text(title).crayonType(.head).foregroundStyle(CrayonColor.ink)
                CrayonTabs(selection: $selection, items: tabs.map { ($0.0, $0.1, nil) },
                           itemSize: CGSize(width: 150, height: 64), spacing: Spacing.sm)
                if selection == dateChoice {
                    DateField(label: dateLabel, date: $date)
                }
                if let caption {
                    Text(caption).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: Spacing.l) {
                    InkButton(save, action: onSave).frame(width: 220)
                    Button(action: onCancel) {
                        Text(cancel).crayonType(.head).foregroundStyle(CrayonColor.softText)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 560)
    }
}
