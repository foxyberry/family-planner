import Domain
import XCTest

/// Spec "Event form rows for 6b": Bring, missions before / after on items, days per C5 mission, and
/// the missions each window lists.
final class EventPartsTests: XCTestCase {
    private let kid = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
    private let swim = UUID(uuidString: "00000000-0000-0000-0000-00000000B001")!
    private let art = UUID(uuidString: "00000000-0000-0000-0000-00000000B002")!

    private func thing(_ n: Int, _ name: String, _ picture: String) -> ItemMission {
        ItemMission(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!, name: name, picture: picture)
    }

    private func item(_ id: UUID, before: [ItemMission] = [], bring: [ItemMission] = [],
                      after: [ItemMission] = []) -> ScheduleItem {
        ScheduleItem(id: id, title: "Swimming", iconName: "actSwim", audience: .kid(kid), start: 960, end: 1020,
                     recurrence: .once(Day(year: 2026, month: 11, day: 10)), skippedDays: [], skipsHolidays: false,
                     showsStar: false, trip: Trip(way: .walk, leaveBefore: 10), bring: bring,
                     missionsBefore: before, missionsAfter: after)
    }

    private func mission(_ n: Int, _ name: String, _ picture: String, days: Set<Weekday> = Set(Weekday.allCases)) -> Mission {
        Mission(id: UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", 100 + n))!, kid: kid, name: name,
                picture: picture, order: n, days: days)
    }

    func testListsKeepFourAtMost() {
        let five = (1...5).map { thing($0, "Thing", "backpack") }
        let item = item(swim, before: five, bring: five, after: five)
        XCTAssertEqual(item.bring.count, 4)
        XCTAssertEqual(item.missionsBefore.count, 4)
        XCTAssertEqual(item.missionsAfter.count, 4)
    }

    func testOldItemsAndMissionsLoadWithEmptyListsAndEveryDay() throws {
        let item = try JSONDecoder().decode(ScheduleItem.self, from: Data("""
        {"id":"\(swim.uuidString)","title":"Swimming","iconName":"actSwim","audience":{"both":{}},
         "start":960,"end":1020,"recurrence":{"once":{"_0":{"year":2026,"month":11,"day":10}}},
         "skippedDays":[],"skipsHolidays":false,"showsStar":false}
        """.utf8))
        XCTAssertEqual(item.bring, [])
        XCTAssertEqual(item.missionsBefore, [])
        XCTAssertEqual(item.missionsAfter, [])
        let mission = try JSONDecoder().decode(Mission.self, from: Data("""
        {"id":"\(swim.uuidString)","kid":"\(kid.uuidString)","name":"Shoes on","picture":"shoe","order":0}
        """.utf8))
        XCTAssertEqual(mission.days, Set(Weekday.allCases))
    }

    func testRoundTripKeepsTheNewParts() throws {
        let original = item(swim, before: [thing(1, "Goggles", "goggles")], bring: [thing(2, "Bag", "backpack")],
                            after: [thing(3, "Hang it", "towel")])
        let copy = try JSONDecoder().decode(ScheduleItem.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(copy, original)
        let thursdays = mission(1, "Library bag", "backpack", days: [.thursday])
        XCTAssertEqual(try JSONDecoder().decode(Mission.self, from: JSONEncoder().encode(thursdays)), thursdays)
    }

    func testTheMorningListsTheWeekdaysMissionsThenTheOutingsBeforeMissionsAndBring() {
        let routine = [mission(2, "Shoes on", "shoe"), mission(1, "Library bag", "libraryBag", days: [.thursday]),
                       mission(0, "Pack bag", "backpack")]
        let swimming = item(swim, before: [thing(1, "Goggles", "goggles")],
                            bring: [thing(2, "Bag", "backpack"), thing(3, "Towel", "towel")])
        let span = WindowSpan(start: 390, end: 425, parts: [.morning, .before(.item(swim))])
        let tuesday = DayPlanner.missions(in: span, routine: routine, items: [swimming], weekday: .tuesday)
        XCTAssertEqual(tuesday.map(\.name), ["Pack bag", "Shoes on", "Goggles", "Towel"],
                       "Thursday's library bag is left out, and the bag shows once")
        XCTAssertEqual(tuesday.map(\.window), [.morning, .morning, .before(.item(swim)), .before(.item(swim))])
        let thursday = DayPlanner.missions(in: span, routine: routine, items: [swimming], weekday: .thursday)
        XCTAssertEqual(thursday.first?.name, "Pack bag")
        XCTAssertTrue(thursday.contains { $0.name == "Library bag" })
    }

    func testAfterHomeListsEachEndedEventsAfterMissions() {
        let swimming = item(swim, after: [thing(1, "Hang it", "towel")])
        let drawing = item(art, after: [thing(2, "Wash brushes", "paintBrush")])
        let span = WindowSpan(start: 1035, end: 1080, parts: [.after(.school), .after(.item(swim)), .after(.item(art))])
        let list = DayPlanner.missions(in: span, routine: [], items: [swimming, drawing], weekday: .monday)
        XCTAssertEqual(list.map(\.name), ["Hang it", "Wash brushes"])
        XCTAssertEqual(list.map(\.window), [.after(.item(swim)), .after(.item(art))])
    }
}
