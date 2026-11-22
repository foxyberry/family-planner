import Domain
import Foundation
import Strings

/// Board G5 "Change from when?" (spec G5 and "Edit scope", layout v69), for G1 (Our day), G2 (the
/// item editor) and G4 (Edit School): the middle tab names the changed series' next day itself
/// ("Tomorrow", or its short date "Wed 18 Nov"; never "Next Wed", which reads as next week), is hidden
/// when the series has no day in the next 14 days, and the card opens on the day being looked at.
public enum FromWhenTabs {
    public typealias Choice = ItemEditorFeature.FromWhen

    /// How many days after today the middle tab looks.
    public static let reach = 14

    /// The first day after today, at most `reach` days ahead, that `isDay` takes; nil hides the tab.
    public static func nextDay(after today: Day, calendar: Calendar, isDay: (Day) -> Bool) -> Day? {
        (1...reach).lazy.map { today.adding(days: $0, calendar: calendar) }.first(where: isDay)
    }

    /// The first day after today, at most `reach` days ahead, that a repeating item has within its Runs
    /// (spec G5 "The middle tab's day"): one of its weekdays every week, its day of the month ("2nd Sat",
    /// "Day 14") every month; never before its start or after its end. Give the recurrence with its end
    /// worked out (`FamilyCalendar.resolving`): an "End of term" or "After n times" run keeps none.
    public static func nextDay(of recurrence: Recurrence, after today: Day, calendar: Calendar) -> Day? {
        nextDay(after: today, calendar: calendar) { day in
            guard recurrence.pattern(on: day, calendar: calendar) else { return false }
            guard let range = recurrence.range else { return true }
            return day >= range.from && range.until.map { day <= $0 } ?? true
        }
    }

    /// "Today", then the next day when there is one, then "Date".
    public static func tabs(next: Day?, today: Day, calendar: Calendar) -> [(Choice, String)] {
        let middle = next.map { [(Choice.next, title(of: $0, today: today, calendar: calendar))] } ?? []
        return [(.today, L10n.tr("from_when.today"))] + middle + [(.date, L10n.tr("from_when.date"))]
    }

    /// "Tomorrow" when `day` is tomorrow, else "Wed 18 Nov".
    static func title(of day: Day, today: Day, calendar: Calendar) -> String {
        day == today.adding(days: 1, calendar: calendar) ? L10n.tr("from_when.tomorrow")
            : DayText.short(day, calendar: calendar)
    }

    /// The choice and date the card opens on. A day after today being looked at opens on the middle
    /// tab when it is that day, else on "Date" with that day; today, an earlier day (the split is never
    /// before today) or none (G2 / G4 from the List) open on "Today".
    public static func opening(shown: Day?, next: Day?, today: Day) -> (choice: Choice, date: Day) {
        guard let shown, shown > today else { return (.today, today) }
        return (shown == next ? .next : .date, shown)
    }
}
