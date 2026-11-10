import CrayonKit
import SwiftUI

/// Board G1's day button (382 × 72, the off-tab look): "Today" (bold) and "Tue 10 Nov" (soft), or
/// only the date (bold) on another day, then a down chevron.
public struct DayButton: View {
    private let today: String?
    private let date: String
    private let action: () -> Void

    public init(today: String?, date: String, action: @escaping () -> Void) {
        self.today = today
        self.date = date
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if let today {
                    Text(today).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink)
                    Text(date).crayonType(.body).foregroundStyle(CrayonColor.softText)
                } else {
                    Text(date).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink)
                }
                Spacer(minLength: 0)
                MarkerIcon(.chevronDown, size: 28, color: CrayonColor.softText)
            }
            .padding(.horizontal, Spacing.m)
            .frame(maxWidth: .infinity, minHeight: 72)
            .partBackground(.capsule, fill: CrayonStyle.paper, seed: CrayonStyle.Seed.dayButton)
        }
        .buttonStyle(.plain)
    }
}

/// Board G1c: the month (head) with ‹ ›, two weeks of compact date chips (today underlined, the
/// picked day in sky) and a "Today" link. 600 wide.
public struct DayPickerCard: View {
    /// One date chip; `index` is its place in the two weeks (0 … 13).
    public struct Chip: Equatable, Identifiable, Sendable {
        public var index: Int
        public var weekday: String
        public var day: Int
        public var isPicked: Bool
        public var isToday: Bool
        public var id: Int { index }

        public init(index: Int, weekday: String, day: Int, isPicked: Bool, isToday: Bool) {
            self.index = index
            self.weekday = weekday
            self.day = day
            self.isPicked = isPicked
            self.isToday = isToday
        }
    }

    private let month: String
    private let weeks: [[Chip]]
    private let labels: (earlier: String, later: String, today: String)
    private let onPage: (Int) -> Void
    private let onPick: (Int) -> Void
    private let onToday: () -> Void

    public init(month: String, weeks: [[Chip]], earlier: String, later: String, today: String,
                onPage: @escaping (Int) -> Void, onPick: @escaping (Int) -> Void, onToday: @escaping () -> Void) {
        self.month = month
        self.weeks = weeks
        labels = (earlier, later, today)
        self.onPage = onPage
        self.onPick = onPick
        self.onToday = onToday
    }

    public var body: some View {
        PaperCard(seed: CrayonStyle.Seed.dayPicker) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack {
                    Text(month).crayonType(.head).foregroundStyle(CrayonColor.ink)
                    Spacer()
                    RoundButton(glyph: .chevronLeft, accessibilityLabel: labels.earlier) { onPage(-1) }.size(64)
                    RoundButton(glyph: .chevronRight, accessibilityLabel: labels.later) { onPage(1) }.size(64)
                }
                ForEach(weeks.indices, id: \.self) { week in
                    HStack(spacing: Spacing.xxs) {
                        ForEach(weeks[week]) { chip in
                            DateChip(weekday: chip.weekday, day: chip.day, isOn: chip.isPicked, isToday: chip.isToday,
                                     compact: true) { onPick(chip.index) }
                        }
                    }
                }
                Button(action: onToday) {
                    Text(labels.today).crayonType(.body, bold: true).foregroundStyle(CrayonColor.link)
                }
                .buttonStyle(.plain)
            }
        }
        // Seven 74-wide chips 4 apart fit inside; "Wed" needs the 74 at the 24 caption size.
        .frame(width: 600)
    }
}

/// Board G1d: "Save the changes?", the change in one line (its "→" drawn with a glyph), then Save
/// (ink) · "Don't save" (lateText) · Cancel.
public struct SaveChangesCard: View {
    private let title: String
    private let line: String?
    private let save: String
    private let discard: String
    private let cancel: String
    private let onSave: () -> Void
    private let onDiscard: () -> Void
    private let onCancel: () -> Void

    /// `line` holds one `%@` where the arrow goes.
    public init(title: String, line: String?, save: String, discard: String, cancel: String,
                onSave: @escaping () -> Void, onDiscard: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.title = title
        self.line = line
        self.save = save
        self.discard = discard
        self.cancel = cancel
        self.onSave = onSave
        self.onDiscard = onDiscard
        self.onCancel = onCancel
    }

    public var body: some View {
        PaperCard(seed: CrayonStyle.Seed.saveChanges) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text(title).crayonType(.head).foregroundStyle(CrayonColor.ink)
                if let line {
                    GlyphText(line, glyph: .arrowRight, type: .body, color: CrayonColor.softText)
                }
                // Board G1d: Save 170 wide, the two words 24 apart on one line each.
                HStack(spacing: Spacing.m) {
                    InkButton(save, height: 80, action: onSave).frame(width: 170)
                    Button(action: onDiscard) {
                        Text(discard).crayonType(.body, bold: true).foregroundStyle(CrayonColor.lateText).fixedSize()
                    }
                    .buttonStyle(.plain)
                    Button(action: onCancel) {
                        Text(cancel).crayonType(.body, bold: true).foregroundStyle(CrayonColor.softText).fixedSize()
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(minHeight: 300, alignment: .topLeading)
        }
        .frame(width: 560)
    }
}
