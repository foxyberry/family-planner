import Domain
import Foundation

/// Shared test values: Singapore calendar, Monday 9 Nov 2026, Kid A (school) and Kid B (home).
enum Fixture {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return calendar
    }()

    static let monday = Day(year: 2026, month: 11, day: 9)
    static let tuesday = Day(year: 2026, month: 11, day: 10)
    static let wednesday = Day(year: 2026, month: 11, day: 11)
    static let thursday = Day(year: 2026, month: 11, day: 12)
    static let saturday = Day(year: 2026, month: 11, day: 14)
    static let sunday = Day(year: 2026, month: 11, day: 15)
    /// Every fixture template starts on this day.
    static let templatesFrom = Day(year: 2026, month: 11, day: 1)

    static let kidA = Kid(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!, name: "Kid A",
                          colorIndex: 0, age: 8, schoolYear: "Year 3",
                          school: School(name: "Example Primary School", days: Weekday.schoolDays,
                                         start: 480, end: 900))
    static let kidB = Kid(id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!, name: "Kid B",
                          colorIndex: 1, age: 4, schoolYear: nil, school: nil)

    static func block(_ title: String, _ kind: SlotKind, _ start: Int, _ end: Int) -> RoutineBlock {
        RoutineBlock(title: title, iconName: "actPlay", kind: kind, start: start, end: end)
    }

    static let routines: [Routine] = [
        Routine(kid: kidA.id, dayType: .weekday, from: templatesFrom, blocks: [
            block("Sleep", .sleep, 0, 420), block("Breakfast", .morning, 420, 465),
            block("School", .school, 480, 900), block("Play", .play, 900, 1020),
            block("Dinner", .dinner, 1080, 1140), block("Sleep", .sleep, 1230, 1440),
        ]),
        Routine(kid: kidA.id, dayType: .saturday, from: templatesFrom, blocks: [
            block("Sleep", .sleep, 0, 480), block("Play", .play, 480, 1080), block("Sleep", .sleep, 1230, 1440),
        ]),
        Routine(kid: kidA.id, dayType: .sunday, from: templatesFrom, blocks: [
            block("Sleep", .sleep, 0, 510), block("Lazy", .play, 510, 1080), block("Sleep", .sleep, 1230, 1440),
        ]),
        Routine(kid: kidB.id, dayType: .weekday, from: templatesFrom, blocks: [
            block("Sleep", .sleep, 0, 420), block("Nap", .sleep, 780, 870), block("Sleep", .sleep, 1170, 1440),
        ]),
        Routine(kid: kidB.id, dayType: .saturday, from: templatesFrom, blocks: [
            block("Sleep", .sleep, 0, 450), block("Sleep", .sleep, 1170, 1440),
        ]),
        Routine(kid: kidB.id, dayType: .sunday, from: templatesFrom, blocks: [
            block("Sleep", .sleep, 0, 450), block("Sleep", .sleep, 1170, 1440),
        ]),
    ]

    static func weekly(_ title: String = "Swimming", days: Set<Weekday> = [.monday, .wednesday],
                       start: Int = 930, end: Int = 990, audience: Audience? = nil,
                       from: Day = Day(year: 2026, month: 11, day: 1), until: Day? = nil,
                       skipsHolidays: Bool = true) -> ScheduleItem {
        ScheduleItem(id: UUID(), title: title, iconName: "actSwim", audience: audience ?? .kid(kidA.id),
                     start: start, end: end, recurrence: .weekly(days, from: from, until: until),
                     skippedDays: [], skipsHolidays: skipsHolidays, showsStar: false)
    }

    static func once(_ title: String = "Party", on day: Day = monday, start: Int = 960, end: Int = 1080,
                     audience: Audience? = nil) -> ScheduleItem {
        ScheduleItem(id: UUID(), title: title, iconName: "cake", audience: audience ?? .kid(kidA.id),
                     start: start, end: end, recurrence: .once(day), skippedDays: [], skipsHolidays: false,
                     showsStar: true)
    }

    static func slots(on day: Day = monday, kid: Kid = kidA, routines: [Routine] = routines,
                      items: [ScheduleItem] = [], holidays: Set<Day> = []) -> [Slot] {
        DayPlanner.slots(on: day, kid: kid, routines: routines, items: items, holidays: holidays, calendar: calendar)
    }
}
