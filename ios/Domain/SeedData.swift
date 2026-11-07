import Foundation

/// The fake family the app starts with until first-run setup (M4) exists. Public repo: fake names,
/// a made-up school and ordinary example times, never a real timetable.
public enum SeedData {
    public static let kidA = Kid(
        id: UUID(uuidString: "5EED0000-0000-4000-8000-00000000000A")!, name: "Kid A", colorIndex: 0, age: 8,
        schoolYear: "Year 3",
        school: School(name: "Example Primary School", days: Weekday.schoolDays, start: 480, end: 900))

    public static let kidB = Kid(
        id: UUID(uuidString: "5EED0000-0000-4000-8000-00000000000B")!, name: "Kid B", colorIndex: 1, age: 4,
        schoolYear: nil, school: nil)

    public static var kids: [Kid] { [kidA, kidB] }

    private static func block(_ title: String, _ icon: String, _ kind: SlotKind, _ start: Int, _ end: Int) -> RoutineBlock {
        RoutineBlock(title: title, iconName: icon, kind: kind, start: start, end: end)
    }

    public static var routines: [Routine] {
        [
            Routine(kid: kidA.id, dayKind: .schoolDay, blocks: [
                block("Sleep", "actSleep", .sleep, 0, 420), block("Breakfast", "actBreakfast", .morning, 420, 465),
                block("School", "actSchool", .school, 480, 900), block("Play", "actPlay", .play, 900, 1080),
                block("Dinner", "actDinner", .dinner, 1080, 1140), block("Bath", "actShower", .evening, 1140, 1200),
                block("Story", "actStory", .evening, 1200, 1230), block("Sleep", "actSleep", .sleep, 1230, 1440),
            ]),
            Routine(kid: kidA.id, dayKind: .dayOff, blocks: [
                block("Sleep", "actSleep", .sleep, 0, 480), block("Breakfast", "actBreakfast", .morning, 480, 540),
                block("Play", "actPlay", .play, 540, 1080), block("Dinner", "actDinner", .dinner, 1080, 1140),
                block("Bath", "actShower", .evening, 1140, 1200), block("Sleep", "actSleep", .sleep, 1230, 1440),
            ]),
            Routine(kid: kidB.id, dayKind: .schoolDay, blocks: [
                block("Sleep", "actSleep", .sleep, 0, 420), block("Breakfast", "actBreakfast", .morning, 420, 480),
                block("Play", "actPlay", .play, 480, 780), block("Nap", "teddy", .sleep, 780, 870),
                block("Play", "actPlay", .play, 870, 1080), block("Dinner", "actDinner", .dinner, 1080, 1140),
                block("Bath", "actShower", .evening, 1140, 1170), block("Sleep", "actSleep", .sleep, 1170, 1440),
            ]),
            Routine(kid: kidB.id, dayKind: .dayOff, blocks: [
                block("Sleep", "actSleep", .sleep, 0, 450), block("Breakfast", "actBreakfast", .morning, 450, 510),
                block("Play", "actPlay", .play, 510, 780), block("Nap", "teddy", .sleep, 780, 870),
                block("Play", "actPlay", .play, 870, 1080), block("Dinner", "actDinner", .dinner, 1080, 1140),
                block("Bath", "actShower", .evening, 1140, 1170), block("Sleep", "actSleep", .sleep, 1170, 1440),
            ]),
        ]
    }

    /// Two every-week items for Kid A and one just-once event for both kids, two days after `today`.
    public static func items(today: Day, calendar: Calendar) -> [ScheduleItem] {
        let start = today.adding(days: -7, calendar: calendar)
        return [
            ScheduleItem(id: UUID(uuidString: "5EED0000-0000-4000-8000-000000000101")!, title: "Swimming",
                         iconName: "actSwim", audience: .kid(kidA.id), start: 930, end: 990,
                         recurrence: .weekly([.monday, .wednesday], from: start, until: nil), skippedDays: [],
                         skipsHolidays: true, showsStar: false),
            ScheduleItem(id: UUID(uuidString: "5EED0000-0000-4000-8000-000000000102")!, title: "Art",
                         iconName: "actArt", audience: .kid(kidA.id), start: 930, end: 1020,
                         recurrence: .weekly([.thursday], from: start, until: nil), skippedDays: [],
                         skipsHolidays: true, showsStar: false),
            ScheduleItem(id: UUID(uuidString: "5EED0000-0000-4000-8000-000000000201")!, title: "Birthday party",
                         iconName: "cake", audience: .both, start: 960, end: 1080,
                         recurrence: .once(today.adding(days: 2, calendar: calendar)), skippedDays: [],
                         skipsHolidays: false, showsStar: true),
        ]
    }
}
