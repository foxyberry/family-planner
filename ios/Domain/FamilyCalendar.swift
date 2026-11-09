import Foundation

/// The family's year (spec "Repeats, dates and changes"): each kid's school calendar and the public
/// holidays. It gives each kid's days off and works out "End of term" runs.
public struct FamilyCalendar: Equatable, Sendable {
    public var schools: [Kid.ID: SchoolCalendar]
    public var publicHolidays: Set<Day>

    public init(schools: [Kid.ID: SchoolCalendar] = [:], publicHolidays: Set<Day> = []) {
        self.schools = schools
        self.publicHolidays = publicHolidays
    }

    /// A kid's days off: the school's closed days and the public holidays.
    public func daysOff(_ kid: Kid.ID) -> Set<Day> {
        (schools[kid] ?? .none).daysOff(publicHolidays: publicHolidays)
    }

    /// The days off for an item's audience: the kid's own, or for both kids the days off for both.
    public func daysOff(for audience: Audience) -> Set<Day> {
        switch audience {
        case let .kid(id): return daysOff(id)
        case .both:
            let kids = Array(schools.keys)
            guard let first = kids.first else { return publicHolidays }
            return kids.dropFirst().reduce(daysOff(first)) { $0.intersection(daysOff($1)) }
        }
    }

    /// The last day of the term a run starting on `from` is in (for both kids, the earlier end).
    public func termEnd(for audience: Audience, from: Day) -> Day? {
        switch audience {
        case let .kid(id): schools[id]?.termEnd(from: from)
        case .both: schools.values.compactMap { $0.termEnd(from: from) }.min()
        }
    }

    /// The items with their runs' ends worked out: "End of term" on the term's last day, "After n
    /// times" on the nth day it happens (days off skipped when the item skips school holidays).
    public func resolving(_ items: [ScheduleItem], calendar: Calendar) -> [ScheduleItem] {
        items.map { item in
            guard case let .weekly(days, from, _) = item.recurrence else { return item }
            var copy = item
            switch item.runsEnd {
            case .term?:
                copy.recurrence = .weekly(days, from: from, until: termEnd(for: item.audience, from: from))
            case let .count(times)?:
                copy.recurrence = .weekly(days, from: from, until: nthDay(of: copy, times: times, calendar: calendar))
            case .date?, .none?, nil:
                break
            }
            return copy
        }
    }

    /// The day an open-ended weekly item happens for the `times`th time (two years at most).
    private func nthDay(of item: ScheduleItem, times: Int, calendar: Calendar) -> Day? {
        guard case let .weekly(days, from, _) = item.recurrence, times > 0 else { return nil }
        var open = item
        open.recurrence = .weekly(days, from: from, until: nil)
        let off = daysOff(for: item.audience)
        var count = 0
        for offset in 0..<730 {
            let day = from.adding(days: offset, calendar: calendar)
            guard DayPlanner.matches(open, on: day, holidays: off, calendar: calendar) else { continue }
            count += 1
            if count == times { return day }
        }
        return nil
    }
}
