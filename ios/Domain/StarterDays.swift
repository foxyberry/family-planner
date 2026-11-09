import Foundation
import Strings

/// The day templates and morning missions a kid gets from first-run setup (S1–S4), shaped like the
/// seed (spec "Seed data in M2"): grown-ups change them later in Our kids (C5, C6).
public enum StarterDays {
    /// Wake-up when school does not start earlier, dinner, and bedtime on school days.
    static let wake = 390
    static let dinner = 1110
    static let weekendBlocks: [(String, String, SlotKind, Int, Int)] = [
        ("sleep", "actSleep", .sleep, 0, 450), ("breakfast", "actBreakfast", .morning, 450, 510),
        ("play", "actPlay", .play, 510, 1140), ("dinner", "actDinner", .dinner, 1140, 1215),
        ("shower", "actShower", .evening, 1215, 1245), ("sleep", "actSleep", .sleep, 1245, 1440),
    ]
    static let homeBlocks: [(String, String, SlotKind, Int, Int)] = [
        ("sleep", "actSleep", .sleep, 0, 390), ("breakfast", "actBreakfast", .morning, 390, 450),
        ("play", "blocks", .play, 450, 780), ("nap", "teddy", .sleep, 780, 900),
        ("snack", "snack", .play, 900, 960), ("play", "actPlay", .play, 960, 1080),
        ("dinner", "actDinner", .dinner, 1080, 1125), ("shower", "actShower", .evening, 1125, 1170),
        ("sleep", "actSleep", .sleep, 1170, 1440),
    ]

    /// Mon–Fri, Sat and Sun templates from `from`. A kid with a school (or preschool, its own block
    /// "Preschool") is there from `arriveBy`
    /// (the school's start when nil) until the school ends, getting there by `trip`; a kid without
    /// one has the same home day all week.
    public static func routines(for kid: Kid, trip: Trip?, from: Day) -> [Routine] {
        guard let school = kid.school else {
            return DayType.allCases.map { Routine(kid: kid.id, dayType: $0, from: from, blocks: blocks(homeBlocks)) }
        }
        let start = min(max(school.arriveBy ?? school.start, 60), 1380)
        let end = min(max(school.end, start + 30), 1410)
        let wake = min(Self.wake, start - 30)
        let dinner = max(Self.dinner, end)
        let shower = min(dinner + 45, 1440)
        let bed = min(shower + 45, 1440)
        let weekday: [(String, String, SlotKind, Int, Int)] = [
            ("sleep", "actSleep", .sleep, 0, wake), ("breakfast", "actBreakfast", .morning, wake, start),
            school.isPreschool ? ("preschool", "playground", .school, start, end) : ("school", "actSchool", .school, start, end),
            ("free", "", .free, end, dinner),
            ("dinner", "actDinner", .dinner, dinner, shower), ("shower", "actShower", .evening, shower, bed),
            ("sleep", "actSleep", .sleep, bed, 1440),
        ]
        let weekdayBlocks = blocks(weekday).map { block in
            guard block.kind == .school else { return block }
            var school = block
            school.isLocked = true
            school.trip = trip
            return school
        }
        return [
            Routine(kid: kid.id, dayType: .weekday, from: from, blocks: weekdayBlocks),
            Routine(kid: kid.id, dayType: .saturday, from: from, blocks: blocks(weekendBlocks)),
            Routine(kid: kid.id, dayType: .sunday, from: from, blocks: blocks(weekendBlocks)),
        ]
    }

    /// The morning missions: getting ready for school, or a short list for a kid at home.
    public static func missions(for kid: Kid, id: () -> UUID) -> [Mission] {
        let list: [(String, String)] = kid.school == nil
            ? [("wake", "sun"), ("brush", "toothbrush"), ("shoes", "shoe")]
            : [("wake", "sun"), ("brush", "toothbrush"), ("dressed", "shirt"), ("breakfast", "actBreakfast"),
               ("bag", "backpack"), ("shoes", "shoe")]
        return list.enumerated().map { order, mission in
            Mission(id: id(), kid: kid.id, name: missionName(mission.0), picture: mission.1, order: order)
        }
    }

    private static func blocks(_ list: [(String, String, SlotKind, Int, Int)]) -> [RoutineBlock] {
        list.filter { $0.3 < $0.4 }.map { title, icon, kind, start, end in
            RoutineBlock(title: blockTitle(title), iconName: icon, kind: kind, start: start, end: end)
        }
    }

    private static func blockTitle(_ id: String) -> String {
        switch id {
        case "sleep": L10n.tr("starter.sleep")
        case "breakfast": L10n.tr("starter.breakfast")
        case "school": L10n.tr("starter.school")
        case "preschool": L10n.tr("starter.preschool")
        case "free": L10n.tr("starter.free")
        case "dinner": L10n.tr("starter.dinner")
        case "shower": L10n.tr("starter.shower")
        case "nap": L10n.tr("starter.nap")
        case "snack": L10n.tr("starter.snack")
        default: L10n.tr("starter.play")
        }
    }

    private static func missionName(_ id: String) -> String {
        switch id {
        case "wake": L10n.tr("starter.mission.wake")
        case "brush": L10n.tr("starter.mission.brush")
        case "dressed": L10n.tr("starter.mission.dressed")
        case "breakfast": L10n.tr("starter.mission.breakfast")
        case "bag": L10n.tr("starter.mission.bag")
        default: L10n.tr("starter.mission.shoes")
        }
    }
}
