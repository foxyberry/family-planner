import Domain
import Foundation

public struct HubRow: Equatable, Sendable {
    public var key: String
    public var value: String

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

/// A titled block of the About card. The school's days are their own row kind, drawn as day chips.
public struct HubSection: Equatable, Sendable {
    public enum Row: Equatable, Sendable {
        case text(HubRow)
        case schoolDays(key: String, days: Set<Weekday>)
    }

    public var title: String
    public var rows: [Row]

    public init(title: String, rows: [Row]) {
        self.title = title
        self.rows = rows
    }
}

public struct HubItemRow: Equatable, Identifiable, Sendable {
    public var id: ScheduleItem.ID
    public var iconName: String
    public var title: String
    public var detail: String
}

/// The text of the Our kids hub (boards C1, E6).
public enum HubModel {
    /// About, then School for a school kid, or Nursery and Morning for a kid at home.
    public static func sections(kid: Kid, routines: [Routine]) -> [HubSection] {
        let about = HubSection(title: "About", rows: aboutRows(kid: kid, routines: routines).map(HubSection.Row.text))
        guard let school = kid.school else {
            return [about,
                    HubSection(title: "Nursery", rows: [.text(HubRow(key: "Nursery", value: "Not yet"))]),
                    HubSection(title: "Morning", rows: [.text(HubRow(key: "Taps", value: "A grown-up taps for now"))])]
        }
        var rows = schoolRows(kid: kid).map(HubSection.Row.text)
        rows.insert(.schoolDays(key: "Days", days: school.days), at: 1)
        return [about, HubSection(title: "School", rows: rows)]
    }

    /// The heading over the every-week items.
    public static func weeklyHeading(kid: Kid) -> String { kid.school == nil ? "Every week" : "After school" }

    public static func aboutRows(kid: Kid, routines: [Routine]) -> [HubRow] {
        let blocks = routines.first { $0.kid == kid.id && $0.dayKind == .schoolDay }?.blocks ?? []
        let sleeps = blocks.filter { $0.kind == .sleep }
        let wake = sleeps.first { $0.start == 0 }?.end
        let bed = sleeps.first { $0.end == 1440 }?.start
        let nap = sleeps.first { $0.start != 0 && $0.end != 1440 }
        let age = kid.school == nil ? "\(kid.age) · at home" : "\(kid.age) · \(kid.schoolYear ?? "")"
        var day: [String] = []
        if kid.school != nil, let wake { day.append("Up \(TimeText.clock(wake))") }
        if let nap { day.append("Nap \(TimeText.clock(nap.start))–\(TimeText.clock(nap.end))") }
        if let bed { day.append("Bed \(TimeText.clock(bed))") }
        return [HubRow(key: "Age", value: age), HubRow(key: "Day", value: day.joined(separator: " · "))]
    }

    /// School name, hours and holidays (`sections` adds the school days after the name).
    public static func schoolRows(kid: Kid) -> [HubRow] {
        guard let school = kid.school else { return [] }
        return [
            HubRow(key: "School", value: school.name),
            HubRow(key: "Hours", value: "\(TimeText.withPeriod(school.start)) – \(TimeText.withPeriod(school.end))"),
            HubRow(key: "Holidays", value: "No holidays set"),
        ]
    }

    /// Every-week items for `kid` that are still running (stopped or replaced series stay in past days only).
    public static func weeklyRows(kid: Kid, items: [ScheduleItem]) -> [HubItemRow] {
        items.compactMap { item -> (ScheduleItem, Set<Weekday>)? in
            guard item.audience.includes(kid.id), case let .weekly(days, _, until) = item.recurrence, until == nil
            else { return nil }
            return (item, days)
        }
        .sorted { ($0.0.start, $0.0.title) < ($1.0.start, $1.0.title) }
        .map { item, days in
            HubItemRow(id: item.id, iconName: item.iconName, title: item.title,
                       detail: "\(DayText.chips(days)) \(TimeText.clock(item.start))–\(TimeText.clock(item.end))")
        }
    }

    /// Upcoming just-once items for `kid`, nearest first, at most five. An item stays listed until the
    /// kid's next wake-up after its day.
    public static func onceRows(kid: Kid, items: [ScheduleItem], routines: [Routine], today: Day, nowMinute: Int,
                                calendar: Calendar) -> [HubItemRow] {
        let kind = DayPlanner.dayKind(on: today, kid: kid, holidays: [], calendar: calendar)
        let wake = routines.first { $0.kid == kid.id && $0.dayKind == kind }?.blocks
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
            HubItemRow(id: item.id, iconName: item.iconName, title: item.title,
                       detail: "\(DayText.short(day, calendar: calendar)) · "
                           + "\(TimeText.clock(item.start))–\(TimeText.clock(item.end))")
        }
    }
}
