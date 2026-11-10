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

    /// "Change from when?" (spec "Repeats, dates and changes", board G5): the changed series and the
    /// changed or skipped days it drops because they are no longer days of it.
    public struct Split: Equatable, Sendable {
        public var items: [ScheduleItem]
        public var removed: [Day]
    }

    /// Saves `edit` over `original` from `day` on: the old part ends the day before (days before it
    /// never change) and a new part with `newID` starts that day. A day on or before the series'
    /// start changes the whole series in place. Changed and skipped days from `day` on stay when they
    /// are still days of the new part, and are dropped (listed in `removed`) otherwise.
    public static func splitting(_ original: ScheduleItem, with edit: ScheduleItem, from day: Day, newID: UUID,
                                 calendar: Calendar) -> Split {
        guard case let .weekly(_, oldFrom, _) = original.recurrence,
              case let .weekly(newDays, editFrom, newUntil) = edit.recurrence
        else { return Split(items: [edit], removed: []) }
        func fits(_ date: Day) -> Bool {
            newDays.contains(date.weekday(calendar)) && (newUntil.map { date <= $0 } ?? true)
        }
        let later = { (date: Day) in date >= day }
        let changed = Set(original.skippedDays.filter(later) + original.dayChanges.map(\.day).filter(later))
        let removed = changed.filter { !fits($0) }.sorted()

        var next = edit
        next.skippedDays = original.skippedDays.filter { later($0) && fits($0) }
        next.dayChanges = original.dayChanges.filter { later($0.day) && fits($0.day) }
        guard day > oldFrom else {
            next.id = original.id
            next.recurrence = .weekly(newDays, from: max(editFrom, oldFrom), until: newUntil)
            return Split(items: [next], removed: removed)
        }
        var old = original
        old.recurrence = .weekly(original.weeklyDays, from: oldFrom, until: day.adding(days: -1, calendar: calendar))
        old.runsEnd = .date
        old.skippedDays = original.skippedDays.filter { $0 < day }
        old.dayChanges = original.dayChanges.filter { $0.day < day }
        next.id = newID
        next.recurrence = .weekly(newDays, from: max(day, editFrom), until: newUntil)
        return Split(items: [old, next], removed: removed)
    }

    /// "This day": the item with `day` changed to `edit`'s times, name and picture (only what differs
    /// from the series is kept; a day changed back to the series has no change left).
    public static func changing(_ item: ScheduleItem, on day: Day, to edit: ScheduleItem) -> ScheduleItem {
        var change = DayChange(day: day)
        if edit.start != item.start { change.start = edit.start }
        if edit.end != item.end { change.end = edit.end }
        if edit.title != item.title { change.title = edit.title }
        if edit.iconName != item.iconName { change.iconName = edit.iconName }
        var copy = item
        copy.dayChanges.removeAll { $0.day == day }
        if !change.isEmpty { copy.dayChanges.append(change) }
        return copy
    }
}
