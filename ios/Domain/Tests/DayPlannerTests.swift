import Domain
import Foundation
import XCTest

final class DayPlannerTests: XCTestCase {
    private typealias F = Fixture

    private func titles(_ slots: [Slot], in range: Range<Int>) -> [String] {
        slots.filter { $0.start < range.upperBound && $0.end > range.lowerBound }
            .map { "\($0.title) \($0.start)-\($0.end)" }
    }

    func testWeekdayIsSchoolDayAndWeekendIsDayOff() {
        XCTAssertEqual(DayPlanner.dayKind(on: F.monday, kid: F.kidA, holidays: [], calendar: F.calendar), .schoolDay)
        XCTAssertEqual(DayPlanner.dayKind(on: F.saturday, kid: F.kidA, holidays: [], calendar: F.calendar), .dayOff)
    }

    func testPublicHolidayIsDayOff() {
        XCTAssertEqual(DayPlanner.dayKind(on: F.monday, kid: F.kidA, holidays: [F.monday], calendar: F.calendar),
                       .dayOff)
    }

    func testHomeKidUsesWeekdayRoutineOnWeekdays() {
        XCTAssertEqual(DayPlanner.dayKind(on: F.monday, kid: F.kidB, holidays: [], calendar: F.calendar), .schoolDay)
        XCTAssertEqual(DayPlanner.dayKind(on: F.saturday, kid: F.kidB, holidays: [], calendar: F.calendar), .dayOff)
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
