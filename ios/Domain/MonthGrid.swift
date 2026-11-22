import Foundation

/// One month as the school calendar draws it (spec K1 "Layout"): six weeks of seven days, Monday
/// first whatever the calendar's own first weekday is, with blanks before the 1st and after the
/// last day.
public struct MonthGrid: Equatable, Sendable {
    public let year: Int
    public let month: Int
    /// Six rows of seven (Monday … Sunday); nil outside the month.
    public let weeks: [[Day?]]

    /// Six rows on every card, so the twelve cards line up (board K1).
    public static let rows = 6

    public init(year: Int, month: Int, calendar: Calendar) {
        self.year = year
        self.month = month
        let first = Day(year: year, month: month, day: 1)
        let count = calendar.range(of: .day, in: .month, for: first.date(calendar: calendar))?.count ?? 0
        let lead = first.weekday(calendar).mondayFirstIndex
        let cells: [Day?] = (0..<(Self.rows * 7)).map { index in
            let number = index - lead + 1
            return (1...max(count, 1)).contains(number) && count > 0 ? Day(year: year, month: month, day: number) : nil
        }
        weeks = stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<($0 + 7)]) }
    }

    /// The twelve months of `year`, January first.
    public static func year(_ year: Int, calendar: Calendar) -> [MonthGrid] {
        (1...12).map { MonthGrid(year: year, month: $0, calendar: calendar) }
    }
}
