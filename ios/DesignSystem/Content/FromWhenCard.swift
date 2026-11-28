import CrayonKit
import SwiftUI

/// Board G5 "Change from when?": Today / the next day ("Tomorrow", "Wed 18 Nov") / Date tabs, a date
/// field for Date, an optional caption (days that no longer fit), then Save and Cancel. Used by every
/// Every time save, and by G7's "Starts on".
public struct FromWhenCard<Choice: Hashable>: View {
    /// The board the card follows.
    public enum Board: Sendable {
        /// G5 (layout v69, spec G5 "The card"): 620 wide, padding 38 (`ConfirmCard`'s overlay padding);
        /// tabs "Today" 150, the middle tab 232, "Date" 130 (the first, middle and last of the tabs
        /// given), gap 12; the `ConfirmCard` Save row (InkButton 240 × 72, Cancel body bold, 40 apart).
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
            VStack(alignment: .leading, spacing: 0) {
                Text(title).crayonType(.head).foregroundStyle(CrayonColor.ink)
                // A tab wider than its label keeps its round crayon ends: the capsule is drawn at the
                // tab's size (the board's 9-slice).
                CrayonTabs(selection: $selection, items: tabs.map { ($0.0, $0.1, nil) }, widths: tabWidths,
                           spacing: Spacing.sm)
                    .padding(.top, gap(Spacing.m, outlines: 1))
                if selection == dateChoice {
                    DateField(label: dateLabel, date: $date).padding(.top, dateGap)
                }
                if let caption {
                    Text(caption).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, gap(Spacing.s, outlines: 1))
                }
                HStack(spacing: sizing(Spacing.l)) {
                    InkButton(save, height: saveSize.height, action: onSave).frame(width: sizing(saveSize.width))
                    Button(action: onCancel) { cancelLabel }
                        .buttonStyle(.plain)
                }
                // Save's outline, and the tabs' or the date field's when no caption is between them.
                .padding(.top, gap(Spacing.m, outlines: caption == nil ? 2 : 1))
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

    /// G5 (spec G5 "The card", "Layout balance", "More G5 edges"): title → tabs 24, tabs → Date 16,
    /// tabs or Date → caption 16, the Save row 24 below, measured between drawn edges; the tabs, the date field and Save draw their outline one
    /// inset inside their frame, text none (`outlines`: how many of the two edges are outlines). G7
    /// keeps 24 between frames.
    private func gap(_ drawn: CGFloat, outlines: Int) -> CGFloat {
        switch board {
        case .changeFromWhen: sizing(drawn) - CGFloat(outlines) * sizing.inset
        case .startsOn: sizing(Spacing.m)
        }
    }

    /// G5: the Date field 16 under the tabs, both outlines (spec "More G5 edges"); G7 24 between frames.
    private var dateGap: CGFloat { gap(Spacing.s, outlines: 2) }

    /// G5's Save is `ConfirmCard`'s main button (240 × 72); G7 keeps 220 × 96.
    private var saveSize: CGSize {
        switch board {
        case .changeFromWhen: CGSize(width: CardButton.width, height: 72)
        case .startsOn: CGSize(width: 220, height: 96)
        }
    }

    /// G5's Cancel is `ConfirmCard`'s other choice (body bold, one line, 72 tall); G7 keeps head type.
    @ViewBuilder private var cancelLabel: some View {
        switch board {
        case .changeFromWhen:
            Text(cancel).crayonType(.body, bold: true).foregroundStyle(CrayonColor.softText)
                .lineLimit(1).fixedSize()
                .frame(minHeight: sizing(72))
                .contentShape(Rectangle())
        case .startsOn:
            Text(cancel).crayonType(.head).foregroundStyle(CrayonColor.softText)
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
