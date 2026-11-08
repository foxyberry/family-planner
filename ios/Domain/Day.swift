import Foundation

/// A calendar day without a time or time zone, so "Monday 9 Nov" never shifts with the clock.
public struct Day: Hashable, Comparable, Codable, Sendable {
    public var year: Int
    public var month: Int
    public var day: Int

    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day `date` falls on in `calendar`'s time zone.
    public init(_ date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    public static func < (lhs: Day, rhs: Day) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    /// Minutes after midnight (0–1439) of `date` in `calendar`'s time zone.
    public static func minute(of date: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    /// Midnight at the start of this day, plus `minute` minutes.
    public func date(minute: Int = 0, calendar: Calendar) -> Date {
        let midnight = calendar.date(from: DateComponents(year: year, month: month, day: day))!
        return midnight.addingTimeInterval(TimeInterval(minute * 60))
    }

    public func weekday(_ calendar: Calendar) -> Weekday {
        Weekday(rawValue: calendar.component(.weekday, from: date(calendar: calendar)))!
    }

    public func adding(days: Int, calendar: Calendar) -> Day {
        Day(calendar.date(byAdding: .day, value: days, to: date(calendar: calendar))!, calendar: calendar)
    }
}

/// Weekdays numbered like `Calendar` (Sunday = 1).
public enum Weekday: Int, CaseIterable, Codable, Sendable, Comparable {
    case sunday = 1, monday, tuesday, wednesday, thursday, friday, saturday

    public static let schoolDays: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]

    /// Monday first, the way the day chips read.
    public var mondayFirstIndex: Int { (rawValue + 5) % 7 }

    public static func < (lhs: Weekday, rhs: Weekday) -> Bool { lhs.mondayFirstIndex < rhs.mondayFirstIndex }
}
