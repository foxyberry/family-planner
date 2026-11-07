import Foundation

/// Rules for changing an every-week item without rewriting days that already happened.
public enum SeriesEdits {
    /// The next date the item is on that has not ended yet (today counts until its end time).
    /// Looks at most a year ahead.
    public static func nextOccurrence(of item: ScheduleItem, from day: Day, nowMinute: Int, holidays: Set<Day>,
                                      calendar: Calendar) -> Day? {
        for offset in 0..<366 {
            if offset == 0 && nowMinute >= item.end { continue }
            let candidate = day.adding(days: offset, calendar: calendar)
            if DayPlanner.matches(item, on: candidate, holidays: holidays, calendar: calendar) { return candidate }
        }
        return nil
    }

    public static func skipping(_ item: ScheduleItem, day: Day) -> ScheduleItem {
        var copy = item
        copy.skippedDays.insert(day)
        return copy
    }

    public static func unskipping(_ item: ScheduleItem, day: Day) -> ScheduleItem {
        var copy = item
        copy.skippedDays.remove(day)
        return copy
    }

    /// Ends the series the day before `day`; earlier days stay as they were.
    public static func ending(_ item: ScheduleItem, before day: Day, calendar: Calendar) -> ScheduleItem {
        guard case let .weekly(days, from, _) = item.recurrence else { return item }
        var copy = item
        copy.recurrence = .weekly(days, from: from, until: day.adding(days: -1, calendar: calendar))
        return copy
    }

    /// Saves `edit` over `original` from the next occurrence on. If the item is on today and has
    /// already started (or finished), today keeps the old version: the old series ends today and a
    /// new series with `newID` starts tomorrow, taking over the skipped dates after today.
    public static func applying(edit: ScheduleItem, to original: ScheduleItem, today: Day, nowMinute: Int,
                                newID: UUID, holidays: Set<Day>, calendar: Calendar) -> [ScheduleItem] {
        guard case let .weekly(_, from, _) = original.recurrence,
              case let .weekly(newDays, _, newUntil) = edit.recurrence,
              DayPlanner.matches(original, on: today, holidays: holidays, calendar: calendar),
              nowMinute >= original.start
        else { return [edit] }

        var old = original
        guard case let .weekly(oldDays, _, _) = original.recurrence else { return [edit] }
        old.recurrence = .weekly(oldDays, from: from, until: today)
        old.skippedDays = original.skippedDays.filter { $0 <= today }

        var next = edit
        next.id = newID
        next.recurrence = .weekly(newDays, from: today.adding(days: 1, calendar: calendar), until: newUntil)
        next.skippedDays = edit.skippedDays.filter { $0 > today }
        return [old, next]
    }
}
