import Foundation

/// The sample family: tests, previews and the debug menu's "Load sample family" (the app itself
/// starts empty and runs first-run setup). Public repo: fake names, a made-up school and ordinary
/// example times, never a real timetable.
public enum SeedData {
    public static let kidA = Kid(
        id: UUID(uuidString: "5EED0000-0000-4000-8000-00000000000A")!, name: "Kid A", colorIndex: 0, age: 8,
        schoolYear: "Year 3",
        school: School(name: "Example Primary School", days: Weekday.schoolDays, start: 450, end: 900),
        face: "kidGirl")

    public static let kidB = Kid(
        id: UUID(uuidString: "5EED0000-0000-4000-8000-00000000000B")!, name: "Kid B", colorIndex: 1, age: 4,
        schoolYear: nil, school: nil, face: "kidBoy")

    public static var kids: [Kid] { [kidA, kidB] }

    /// Every seed template starts here, so the debug time machine can visit any recent day.
    public static let templatesFrom = Day(year: 2026, month: 1, day: 1)

    private static func block(_ title: String, _ icon: String, _ kind: SlotKind, _ start: Int, _ end: Int,
                              locked: Bool = false, trip: Trip? = nil) -> RoutineBlock {
        RoutineBlock(title: title, iconName: icon, kind: kind, start: start, end: end, isLocked: locked, trip: trip)
    }

    /// Kid A at school on Mon–Fri (boards A1, E1, C6).
    private static let kidAWeekday = [
        block("Sleep", "actSleep", .sleep, 0, 390), block("Breakfast", "actBreakfast", .morning, 390, 450),
        block("School", "wolfie", .school, 450, 900, locked: true, trip: Trip(way: .bus, leaveBefore: 5)), block("Snack", "snack", .play, 900, 960),
        block("Free time", "", .free, 960, 1020), block("Play", "blocks", .play, 1020, 1110),
        block("Dinner", "actDinner", .dinner, 1110, 1155), block("Shower", "actShower", .evening, 1155, 1200),
        block("Sleep", "actSleep", .sleep, 1200, 1440),
    ]

    /// Kid A on Sat and Sun, and on a weekday school holiday (board E3).
    private static let kidAWeekend = [
        block("Sleep", "actSleep", .sleep, 0, 450), block("Breakfast", "actBreakfast", .morning, 450, 510),
        block("Play", "actPlay", .play, 510, 1140), block("Dinner", "actDinner", .dinner, 1140, 1215),
        block("Shower", "actShower", .evening, 1215, 1245), block("Sleep", "actSleep", .sleep, 1245, 1440),
    ]

    /// Kid B stays at home: the same day all week, wake 6:30, nap 13:00–15:00, bed 19:30.
    private static let kidBEveryDay = [
        block("Sleep", "actSleep", .sleep, 0, 390), block("Breakfast", "actBreakfast", .morning, 390, 450),
        block("Play", "blocks", .play, 450, 780), block("Nap", "teddy", .sleep, 780, 900),
        block("Snack", "snack", .play, 900, 960), block("Play", "actPlay", .play, 960, 1080),
        block("Dinner", "actDinner", .dinner, 1080, 1125), block("Shower", "actShower", .evening, 1125, 1170),
        block("Sleep", "actSleep", .sleep, 1170, 1440),
    ]

    /// Three templates per kid: Mon–Fri, Sat, Sun.
    public static var routines: [Routine] {
        [
            Routine(kid: kidA.id, dayType: .weekday, from: templatesFrom, blocks: kidAWeekday),
            Routine(kid: kidA.id, dayType: .saturday, from: templatesFrom, blocks: kidAWeekend),
            Routine(kid: kidA.id, dayType: .sunday, from: templatesFrom, blocks: kidAWeekend),
        ] + DayType.allCases.map { Routine(kid: kidB.id, dayType: $0, from: templatesFrom, blocks: kidBEveryDay) }
    }

    /// Kid A's every-week items (Swimming, Art club, Weekend school) and the Birthday on the coming
    /// Saturday (today when today is a Saturday) for both kids.
    public static func items(today: Day, calendar: Calendar) -> [ScheduleItem] {
        let start = today.adding(days: -7, calendar: calendar)
        let daysToSaturday = (Weekday.saturday.rawValue - today.weekday(calendar).rawValue + 7) % 7
        func weekly(_ id: String, _ title: String, _ icon: String, _ days: Set<Weekday>, _ startMinute: Int,
                    _ endMinute: Int, skipsHolidays: Bool, trip: Trip? = nil) -> ScheduleItem {
            ScheduleItem(id: UUID(uuidString: "5EED0000-0000-4000-8000-000000000\(id)")!, title: title,
                         iconName: icon, audience: .kid(kidA.id), start: startMinute, end: endMinute,
                         recurrence: .weekly(days, from: start, until: nil), skippedDays: [],
                         skipsHolidays: skipsHolidays, showsStar: false, trip: trip)
        }
        return [
            weekly("101", "Swimming", "actSwim", [.monday, .wednesday], 930, 990, skipsHolidays: true,
                   trip: Trip(way: .car, leaveBefore: 10)),
            weekly("102", "Art club", "actArt", [.friday], 900, 960, skipsHolidays: true),
            weekly("103", "Weekend school", "actLanguageSchool", [.saturday], 540, 720, skipsHolidays: false,
                   trip: Trip(way: .car, leaveBefore: 25)),
            ScheduleItem(id: UUID(uuidString: "5EED0000-0000-4000-8000-000000000201")!, title: "Birthday",
                         iconName: "cake", audience: .both, start: 840, end: 960,
                         recurrence: .once(today.adding(days: daysToSaturday, calendar: calendar)), skippedDays: [],
                         skipsHolidays: false, showsStar: true),
        ]
    }

    /// Spec "MVP data": the seed's morning missions, in screen order.
    public static var missions: [Mission] {
        func mission(_ id: String, _ kid: Kid.ID, _ name: String, _ picture: String, _ order: Int) -> Mission {
            Mission(id: UUID(uuidString: "5EED0000-0000-4000-8000-000000000\(id)")!, kid: kid, name: name,
                    picture: picture, order: order)
        }
        return [
            mission("301", kidA.id, "Wake up", "sun", 0), mission("302", kidA.id, "Brush teeth", "toothbrush", 1),
            mission("303", kidA.id, "Get dressed", "shirt", 2), mission("304", kidA.id, "Breakfast", "actBreakfast", 3),
            mission("305", kidA.id, "Pack bag", "backpack", 4), mission("306", kidA.id, "Shoes on", "shoe", 5),
            mission("311", kidB.id, "Wake up", "sun", 0), mission("312", kidB.id, "Milk", "babyBottle", 1),
            mission("313", kidB.id, "Shoes", "shoe", 2),
        ]
    }
}
