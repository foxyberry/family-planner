import CrayonKit
import SwiftUI

/// Board G1's day button (382 × 72, the off-tab look): "Today" (bold) and "Tue 10 Nov" (soft), or
/// only the date (bold) on another day, then a down chevron.
public struct DayButton: View {
    private let today: String?
    private let date: String
    private let action: () -> Void
    @Environment(\.sizing) private var sizing

    public init(today: String?, date: String, action: @escaping () -> Void) {
        self.today = today
        self.date = date
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: sizing(Spacing.sm)) {
                if let today {
                    Text(today).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink)
                    Text(date).crayonType(.body).foregroundStyle(CrayonColor.softText)
                } else {
                    Text(date).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink)
                }
                Spacer(minLength: 0)
                MarkerIcon(.chevronDown, size: sizing(28), color: CrayonColor.softText)
            }
            .padding(.horizontal, sizing(Spacing.m))
            .frame(maxWidth: .infinity, minHeight: sizing(72))
            .partBackground(.capsule, fill: CrayonStyle.paper, seed: CrayonStyle.Seed.dayButton)
        }
        .buttonStyle(.plain)
    }
}

/// Board G1c: the month (head) with ‹ ›, a weekday header row ("Mon" … "Sun"), two weeks of square
/// date chips with the number only (today underlined, the picked day in sky) and a "Today" link.
/// 600 wide.
public struct DayPickerCard: View {
    /// One date chip; `index` is its place in the two weeks (0 … 13).
    public struct Chip: Equatable, Identifiable, Sendable {
        public var index: Int
        public var day: Int
        public var isPicked: Bool
        public var isToday: Bool
        public var id: Int { index }

        public init(index: Int, day: Int, isPicked: Bool, isToday: Bool) {
            self.index = index
            self.day = day
            self.isPicked = isPicked
            self.isToday = isToday
        }
    }

    private let month: String
    private let weekdays: [String]
    private let weeks: [[Chip]]
    private let today: String
    private let onPage: (Int) -> Void
    private let onPick: (Int) -> Void
    private let onToday: () -> Void
    @Environment(\.sizing) private var sizing

    /// `weekdays`: the header row, one label over each column ("Mon" … "Sun").
    public init(month: String, weekdays: [String], weeks: [[Chip]], today: String,
                onPage: @escaping (Int) -> Void, onPick: @escaping (Int) -> Void, onToday: @escaping () -> Void) {
        self.month = month
        self.weekdays = weekdays
        self.weeks = weeks
        self.today = today
        self.onPage = onPage
        self.onPick = onPick
        self.onToday = onToday
    }

    public var body: some View {
        PaperCard(seed: CrayonStyle.Seed.dayPicker) {
            VStack(alignment: .leading, spacing: sizing(Spacing.s)) {
                HStack {
                    Text(month).crayonType(.head).foregroundStyle(CrayonColor.ink)
                    Spacer()
                    RoundButton(glyph: .chevronLeft) { onPage(-1) }.size(64)
                    RoundButton(glyph: .chevronRight) { onPage(1) }.size(64)
                }
                // Like a calendar: the weekdays once, centred over their columns, then the dates.
                VStack(spacing: sizing(Spacing.sm)) {
                    HStack(spacing: sizing(Spacing.xs)) {
                        ForEach(weekdays.indices, id: \.self) { column in
                            Text(weekdays[column]).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                                .lineLimit(1)
                                .frame(width: sizing(68))
                        }
                    }
                    VStack(spacing: sizing(Spacing.s)) {
                        ForEach(weeks.indices, id: \.self) { week in
                            HStack(spacing: sizing(Spacing.xs)) {
                                ForEach(weeks[week]) { chip in
                                    DateChip(day: chip.day, isOn: chip.isPicked, isToday: chip.isToday) {
                                        onPick(chip.index)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                Button(action: onToday) {
                    Text(today).crayonType(.body, bold: true).foregroundStyle(CrayonColor.link)
                }
                .buttonStyle(.plain)
            }
        }
        // Seven 68-wide chips 8 apart (524) fit the card's inside.
        .frame(width: sizing(600))
    }
}
