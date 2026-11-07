import Domain
import Foundation
import ScheduleStore

enum Fixture {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return calendar
    }()
    static let monday = Day(year: 2026, month: 11, day: 9)

    static func weekly(_ title: String = "Swimming", days: Set<Weekday> = [.monday, .wednesday], start: Int = 930,
                       end: Int = 990, kid: Kid = SeedData.kidA, until: Day? = nil, id: UUID = UUID()) -> ScheduleItem {
        ScheduleItem(id: id, title: title, iconName: "actSwim", audience: .kid(kid.id), start: start, end: end,
                     recurrence: .weekly(days, from: Day(year: 2026, month: 11, day: 1), until: until),
                     skippedDays: [], skipsHolidays: true, showsStar: false)
    }

    static func once(_ title: String, on day: Day, start: Int = 960, end: Int = 1020, audience: Audience = .both,
                     id: UUID = UUID()) -> ScheduleItem {
        ScheduleItem(id: id, title: title, iconName: "cake", audience: audience, start: start, end: end,
                     recurrence: .once(day), skippedDays: [], skipsHolidays: false, showsStar: true)
    }

    static func snapshot(items: [ScheduleItem]) -> ScheduleSnapshot {
        ScheduleSnapshot(kids: SeedData.kids, routines: SeedData.routines, items: items)
    }
}
