import Domain
import Foundation
import XCTest

final class DayPlannerTests: XCTestCase {
    private typealias F = Fixture

    private func titles(_ slots: [Slot], in range: Range<Int>) -> [String] {
        slots.filter { $0.start < range.upperBound && $0.end > range.lowerBound }
            .map { "\($0.title) \($0.start)-\($0.end)" }
    }

    private func dayType(_ day: Day, holidays: Set<Day> = []) -> DayType {
        DayPlanner.dayType(on: day, holidays: holidays, calendar: F.calendar)
    }

    func testWeekdayHolidayUsesSunday() {
        XCTAssertEqual(dayType(F.monday), .weekday)
        XCTAssertEqual(dayType(F.monday, holidays: [F.monday]), .sunday)
        let slots = F.slots(on: F.monday, holidays: [F.monday])
        XCTAssertTrue(slots.contains { $0.title == "Lazy" }, "a weekday holiday draws the Sun template")
        XCTAssertFalse(slots.contains { $0.title == "School" })
    }

    func testSaturdayAndSundayTypes() {
        XCTAssertEqual(dayType(F.saturday), .saturday)
        XCTAssertEqual(dayType(F.sunday), .sunday)
        XCTAssertEqual(dayType(F.saturday, holidays: [F.saturday]), .saturday, "a Saturday holiday is still Sat")
        XCTAssertEqual(DayType.allCases, [.weekday, .saturday, .sunday])
    }

    func testIsDayOffOnWeekendAndHoliday() {
        XCTAssertFalse(DayPlanner.isDayOff(on: F.monday, holidays: [], calendar: F.calendar))
        XCTAssertTrue(DayPlanner.isDayOff(on: F.monday, holidays: [F.monday], calendar: F.calendar))
        XCTAssertTrue(DayPlanner.isDayOff(on: F.saturday, holidays: [], calendar: F.calendar))
        XCTAssertTrue(DayPlanner.isDayOff(on: F.sunday, holidays: [], calendar: F.calendar))
    }

    func testNewestTemplateOnOrBeforeTheDay() {
        let first = Routine(kid: F.kidA.id, dayType: .weekday, from: F.templatesFrom,
                            blocks: [F.block("Old", .play, 600, 700)])
        let second = Routine(kid: F.kidA.id, dayType: .weekday, from: F.thursday,
                             blocks: [F.block("New", .play, 600, 700)])
        let other = Routine(kid: F.kidB.id, dayType: .weekday, from: F.thursday,
                            blocks: [F.block("Other kid", .play, 600, 700)])
        let routines = [second, other, first]
        func template(_ day: Day) -> Routine? {
            DayPlanner.template(for: F.kidA.id, on: day, routines: routines, holidays: [], calendar: F.calendar)
        }
        XCTAssertEqual(template(F.wednesday), first, "a template from tomorrow does not apply today")
        XCTAssertEqual(template(F.thursday), second)
        XCTAssertNil(template(Day(year: 2026, month: 10, day: 30)), "nothing before the first template")
        XCTAssertNil(template(F.saturday), "no Sat template in the list")
        XCTAssertEqual(F.slots(on: F.wednesday, routines: routines).map(\.title), ["Old"])
        XCTAssertEqual(F.slots(on: F.thursday, routines: routines).map(\.title), ["New"])
    }

    func testFreeSlotHasNoPictureButIsASlot() {
        let routine = Routine(kid: F.kidA.id, dayType: .weekday, from: F.templatesFrom, blocks: [
            F.block("Snack", .play, 900, 960),
            RoutineBlock(title: "", iconName: "", kind: .free, start: 960, end: 1020),
        ])
        let slots = F.slots(routines: [routine])
        XCTAssertEqual(slots.map(\.kind), [.play, .free])
        XCTAssertEqual(slots.last?.iconName, "")
        XCTAssertEqual(slots.last?.source, .routine)
        // Something added on top of free time cuts it like any template slot.
        let cut = F.slots(routines: [routine], items: [F.weekly(start: 930, end: 990)])
        XCTAssertEqual(titles(cut, in: 900..<1020), ["Snack 900-930", "Swimming 930-990", " 990-1020"])
    }

    func testBlocksAreUnlockedUnlessSaid() throws {
        XCTAssertFalse(F.block("Play", .play, 0, 60).isLocked)
        let school = RoutineBlock(title: "School", iconName: "actSchool", kind: .school, start: 450, end: 900,
                                  isLocked: true)
        XCTAssertTrue(school.isLocked)
        let routine = Routine(kid: F.kidA.id, dayType: .weekday, from: F.monday, blocks: [school])
        let decoded = try JSONDecoder().decode(Routine.self, from: JSONEncoder().encode(routine))
        XCTAssertEqual(decoded, routine)
    }

    func testWeeklyItemOnItsWeekdaysOnly() {
        let swim = F.weekly()
        XCTAssertTrue(F.slots(on: F.monday, items: [swim]).contains { $0.title == "Swimming" })
        XCTAssertFalse(F.slots(on: F.tuesday, items: [swim]).contains { $0.title == "Swimming" })
        XCTAssertTrue(F.slots(on: F.wednesday, items: [swim]).contains { $0.title == "Swimming" })
    }

    func testWeeklyItemRespectsFromAndUntil() {
        let late = F.weekly(from: F.wednesday)
        XCTAssertFalse(F.slots(on: F.monday, items: [late]).contains { $0.title == "Swimming" })
        let ended = F.weekly(until: F.monday)
        XCTAssertTrue(F.slots(on: F.monday, items: [ended]).contains { $0.title == "Swimming" }, "until is inclusive")
        XCTAssertFalse(F.slots(on: F.wednesday, items: [ended]).contains { $0.title == "Swimming" })
    }

    func testOnceItemOnItsDayOnly() {
        let party = F.once(on: F.saturday)
        let slot = F.slots(on: F.saturday, items: [party]).first { $0.title == "Party" }
        XCTAssertEqual(slot?.source, .once(party.id))
        XCTAssertEqual(slot?.showsStar, true)
        XCTAssertFalse(F.slots(on: F.monday, items: [party]).contains { $0.title == "Party" })
    }

    func testSkippedDayHidesItem() {
        var swim = F.weekly()
        swim.skippedDays = [F.monday]
        XCTAssertFalse(F.slots(on: F.monday, items: [swim]).contains { $0.title == "Swimming" })
        XCTAssertTrue(F.slots(on: F.wednesday, items: [swim]).contains { $0.title == "Swimming" })
    }

    func testHolidaySkipCanBeTurnedOff() {
        XCTAssertFalse(F.slots(items: [F.weekly(skipsHolidays: true)], holidays: [F.monday])
            .contains { $0.title == "Swimming" })
        XCTAssertTrue(F.slots(items: [F.weekly(skipsHolidays: false)], holidays: [F.monday])
            .contains { $0.title == "Swimming" })
    }

    func testAudienceFilters() {
        let forB = F.weekly("Music", audience: .kid(F.kidB.id))
        let forBoth = F.once("Doctor", audience: .both)
        let a = F.slots(kid: F.kidA, items: [forB, forBoth])
        let b = F.slots(kid: F.kidB, items: [forB, forBoth])
        XCTAssertFalse(a.contains { $0.title == "Music" })
        XCTAssertTrue(b.contains { $0.title == "Music" })
        XCTAssertTrue(a.contains { $0.title == "Doctor" })
        XCTAssertTrue(b.contains { $0.title == "Doctor" })
    }

    func testPriorityOnceOverWeeklyOverRoutine() {
        // Routine Play 15:00–17:00, every week 15:30–16:30, just once 16:00–18:00.
        let slots = F.slots(items: [F.weekly(start: 930, end: 990), F.once(start: 960, end: 1080)])
        XCTAssertEqual(titles(slots, in: 900..<1080), ["Play 900-930", "Swimming 930-960", "Party 960-1080"])
        XCTAssertEqual(slots.first { $0.title == "Swimming" }?.kind, .afterSchool)
        XCTAssertEqual(slots.first { $0.title == "Party" }?.kind, .event)
    }

    func testSamePriorityLaterStartCutsEarlier() {
        let slots = F.slots(items: [F.weekly("Art", start: 900, end: 960), F.weekly("Swim", start: 930, end: 1020)])
        XCTAssertEqual(titles(slots, in: 900..<1020), ["Art 900-930", "Swim 930-1020"])
    }

    func testSlotsSortedNeverOverlapNoZeroLength() {
        let cases: [[ScheduleItem]] = [
            [],
            [F.weekly(start: 0, end: 1440)],
            [F.once(start: 420, end: 480), F.weekly(start: 450, end: 600), F.weekly("B", start: 470, end: 500)],
            [F.once(start: 900, end: 900 + 1), F.weekly(start: 899, end: 1021)],
        ]
        for items in cases {
            let slots = F.slots(items: items)
            for slot in slots { XCTAssertLessThan(slot.start, slot.end) }
            for i in slots.indices.dropFirst() { XCTAssertLessThanOrEqual(slots[i - 1].end, slots[i].start) }
        }
    }

    func testNowAndNext() {
        let slots = F.slots(items: [F.weekly()])
        let atSwim = DayPlanner.now(at: 945, in: slots)
        XCTAssertEqual(atSwim.current?.title, "Swimming")
        XCTAssertEqual(atSwim.next?.title, "Play")
        let inGap = DayPlanner.now(at: 1040, in: slots)   // 17:20, between Play and Dinner
        XCTAssertNil(inGap.current)
        XCTAssertEqual(inGap.next?.title, "Dinner")
        let empty = DayPlanner.now(at: 600, in: [])
        XCTAssertNil(empty.current)
        XCTAssertNil(empty.next)
        let afterLast = DayPlanner.now(at: 1440, in: slots)
        XCTAssertNil(afterLast.current)
        XCTAssertNil(afterLast.next)
    }
}
