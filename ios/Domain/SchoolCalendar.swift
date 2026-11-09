import Foundation

/// A school's year (spec "Repeats, dates and changes"): its terms and the weekdays it is closed
/// (vacations, school holidays, public holidays and days off in lieu, from the MOE calendar or the
/// school's own term dates). A kid without one follows public holidays only.
public struct SchoolCalendar: Equatable, Sendable {
    public struct Term: Equatable, Sendable {
        public var name: String
        public var start: Day
        public var end: Day

        public init(name: String, start: Day, end: Day) {
            self.name = name
            self.start = start
            self.end = end
        }
    }

    public var terms: [Term]
    public var closed: Set<Day>

    public init(terms: [Term] = [], closed: Set<Day> = []) {
        self.terms = terms
        self.closed = closed
    }

    public static let none = SchoolCalendar()

    /// The last day of the term `day` is in, or of the next term when `day` is in a break.
    public func termEnd(from day: Day) -> Day? {
        terms.filter { $0.end >= day }.min { $0.start < $1.start }?.end
    }

    /// The days the kid's day is a day off: the school's closed days and the public holidays.
    public func daysOff(publicHolidays: Set<Day>) -> Set<Day> { closed.union(publicHolidays) }
}

/// Which MOE calendar a school follows: its terms and closures differ by level.
public enum MoeCalendarLevel: String, Sendable {
    case kindergarten = "mk"
    case primary, secondary

    /// The level for a kid at an MOE school of `level` (a school with both goes by age: 13 and up
    /// is secondary).
    public static func level(of level: SchoolEntry.MoeLevel, age: Int) -> MoeCalendarLevel {
        switch level {
        case .primary: .primary
        case .secondary: .secondary
        case .primaryAndSecondary: age >= 13 ? .secondary : .primary
        }
    }
}
