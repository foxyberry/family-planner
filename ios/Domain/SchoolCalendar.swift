import Foundation
import Strings

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
    /// The days of the school's own breaks (vacations, school holidays, days off in lieu, a
    /// preschool's closures), each with its break's name ("June holidays"). Public holidays are not
    /// breaks, even where the MOE calendar lists them as closures (spec K1 "Marks": a kid's day off is
    /// drawn in the kid's colour, a public holiday in red). Every break day is also in `closed`.
    public var breaks: [Day: String]
    /// The MOE calendar (Settings reads "MOE 2026 · Term 4 ends 20 Nov"); false for a school's own.
    public var isMoe: Bool

    public init(terms: [Term] = [], closed: Set<Day> = [], breaks: [Day: String] = [:], isMoe: Bool = false) {
        self.terms = terms
        self.closed = closed
        self.breaks = breaks
        self.isMoe = isMoe
    }

    /// A school's own year with the days between its terms as holidays: a school's list names its
    /// mid-term breaks but often not the long ones between terms (user, 2026-11-28: the winter break
    /// between Term 1 and Term 2 was missing). A named break keeps its name; before the first term and
    /// after the last nothing is known, so nothing is added there.
    public func withTermGaps(calendar: Calendar) -> SchoolCalendar {
        var filled = self
        let sorted = terms.sorted { $0.start < $1.start }
        for (term, next) in zip(sorted, sorted.dropFirst()) {
            var day = term.end.adding(days: 1, calendar: calendar)
            while day < next.start {
                filled.closed.insert(day)
                if filled.breaks[day] == nil { filled.breaks[day] = L10n.tr("calendar.term_gap") }
                day = day.adding(days: 1, calendar: calendar)
            }
        }
        return filled
    }

    /// The term `day` is in, or the next one when `day` is in a break.
    public func term(from day: Day) -> Term? {
        terms.filter { $0.end >= day }.min { $0.start < $1.start }
    }

    public static let none = SchoolCalendar()

    /// The last day of the term `day` is in, or of the next term when `day` is in a break.
    public func termEnd(from day: Day) -> Day? { term(from: day)?.end }

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
