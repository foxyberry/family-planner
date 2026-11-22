import CrayonKit
import SwiftUI

/// Board G5 "Change from when?": Today / the next day ("Tomorrow", "Wed 18 Nov") / Date tabs, a date
/// field for Date, an optional caption (days that no longer fit), then Save and Cancel. Used by every
/// All days save, and by G7's "Starts on".
public struct FromWhenCard<Choice: Hashable>: View {
    /// The board the card follows.
    public enum Board: Sendable {
        /// G5 (layout v69): 620 wide, padding 38 (`ConfirmCard`'s overlay padding); tabs "Today" 150,
        /// the middle tab 232, "Date" 130 (the first, middle and last of the tabs given), gap 12.
        case changeFromWhen
        /// G7 "Starts on": 560 wide; tabs "Next term" 184, "Date" 130.
        case startsOn
    }

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
    private let board: Board
    @Environment(\.sizing) private var sizing

    public init(title: String, tabs: [(Choice, String)], selection: Binding<Choice>, dateChoice: Choice,
                dateLabel: String, date: Binding<Date>, caption: String?, save: String, cancel: String,
                board: Board = .changeFromWhen, onSave: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.board = board
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
        PaperCard(seed: 51, padding: padding) {
            VStack(alignment: .leading, spacing: sizing(Spacing.m)) {
                Text(title).crayonType(.head).foregroundStyle(CrayonColor.ink)
                // A tab wider than its label keeps its round crayon ends: the capsule is drawn at the
                // tab's size (the board's 9-slice).
                CrayonTabs(selection: $selection, items: tabs.map { ($0.0, $0.1, nil) }, widths: tabWidths,
                           spacing: Spacing.sm)
                if selection == dateChoice {
                    DateField(label: dateLabel, date: $date)
                }
                if let caption {
                    Text(caption).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: sizing(Spacing.l)) {
                    InkButton(save, action: onSave).frame(width: sizing(220))
                    Button(action: onCancel) {
                        Text(cancel).crayonType(.head).foregroundStyle(CrayonColor.softText)
                    }
                    .buttonStyle(.plain)
                }
            }
            // G5 is 620 wide whether or not the middle tab shows; G7 hugs its content.
            .frame(maxWidth: board == .changeFromWhen ? .infinity : nil, alignment: .leading)
        }
        .frame(width: sizing(width))
    }

    private var width: CGFloat {
        switch board {
        case .changeFromWhen: 620
        case .startsOn: 560
        }
    }

    /// G5 pads like an overlay card; G7 keeps the card's own padding.
    private var padding: EdgeInsets? {
        switch board {
        case .changeFromWhen: ConfirmCard.padding(sizing)
        case .startsOn: nil
        }
    }

    /// Board widths, 72 tall. G5: the first tab 150, the last 130, one between them 232 (two tabs
    /// when the middle one is hidden).
    private var tabWidths: [CGFloat] {
        switch board {
        case .changeFromWhen: tabs.indices.map { $0 == 0 ? 150 : $0 == tabs.count - 1 ? 130 : 232 }
        case .startsOn: [184, 130]
        }
    }
}
