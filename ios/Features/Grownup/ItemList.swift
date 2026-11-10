import Domain
import Foundation
import Strings

/// One schedule item in a list (board G8): its picture, name, days or date, and time.
public struct ItemRow: Equatable, Identifiable, Sendable {
    public var id: ScheduleItem.ID
    public var iconName: String
    public var title: String
    /// "Mon · Wed" or "Sat 14 Nov".
    public var when: String
    /// "3:30–4:30 pm".
    public var time: String

    public init(id: ScheduleItem.ID, iconName: String, title: String, when: String, time: String) {
        self.id = id
        self.iconName = iconName
        self.title = title
        self.when = when
        self.time = time
    }
}

/// The kid's items for the List (board G8).
public enum ItemList {
    /// Every-week items for `kid` that are still running (stopped or replaced series stay in past
    /// days only), by start time.
    public static func weekly(kid: Kid, items: [ScheduleItem]) -> [ItemRow] {
        items.compactMap { item -> (ScheduleItem, Set<Weekday>)? in
            guard item.audience.includes(kid.id), case let .weekly(days, _, until) = item.recurrence, until == nil
            else { return nil }
            return (item, days)
        }
        .sorted { ($0.0.start, $0.0.title) < ($1.0.start, $1.0.title) }
        .map { item, days in
            ItemRow(id: item.id, iconName: item.iconName, title: item.title, when: DayText.chips(days),
                    time: TimeText.range(item.start, item.end))
        }
    }

    /// Upcoming just-once items for `kid`, nearest first, at most five. An item stays listed until the
    /// kid's next wake-up after its day.
    public static func once(kid: Kid, items: [ScheduleItem], routines: [Routine], today: Day, nowMinute: Int,
                            calendar: Calendar) -> [ItemRow] {
        let wake = DayPlanner.template(for: kid.id, on: today, routines: routines, holidays: [], calendar: calendar)?.blocks
            .first { $0.kind == .sleep && $0.start == 0 }?.end ?? 0
        let yesterday = today.adding(days: -1, calendar: calendar)
        return items.compactMap { item -> (ScheduleItem, Day)? in
            guard item.audience.includes(kid.id), case let .once(day) = item.recurrence else { return nil }
            guard day >= today || (day == yesterday && nowMinute < wake) else { return nil }
            return (item, day)
        }
        .sorted { ($0.1, $0.0.start) < ($1.1, $1.0.start) }
        .prefix(5)
        .map { item, day in
            ItemRow(id: item.id, iconName: item.iconName, title: item.title,
                    when: DayText.short(day, calendar: calendar), time: TimeText.range(item.start, item.end))
        }
    }
}
