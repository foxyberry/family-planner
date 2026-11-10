import Domain
import Foundation
import XCTest

/// Spec "Events: one shape for every item": From (linked items), the trip's new fields, a route per
/// event, and data stored by older builds.
final class EventFieldsTests: XCTestCase {
    private typealias F = Fixture

    private func linked(_ item: ScheduleItem, after event: EventRef) -> ScheduleItem {
        var copy = item
        copy.after = event
        copy.trip = nil
        return copy
    }

    func testALinkedItemStartsWhenSchoolEnds() {
        // School 8:00–3:00 pm in the fixture; the item keeps its own 60 minutes.
        let swim = linked(F.weekly("Swimming", days: [.monday], start: 960, end: 1020), after: .school)
        let slot = F.slots(on: F.monday, items: [swim]).first { $0.title == "Swimming" }
        XCTAssertEqual(slot.map { [$0.start, $0.end] }, [900, 960])
    }

    func testALinkedItemIsSkippedWithoutItsEvent() {
        let swim = linked(F.weekly("Swimming", days: [.monday], start: 960, end: 1020), after: .school)
        let holiday = F.slots(on: F.monday, items: [swim], holidays: [F.monday])
        XCTAssertFalse(holiday.contains { $0.title == "Swimming" }, "no school that day, so no swimming after it")
    }

    /// Spec "Repeats, dates and changes", Linked time: "School end + 15 min", length kept.
    func testALinkedItemStartsItsGapAfterSchool() {
        var swim = linked(F.weekly("Swimming", days: [.monday], start: 960, end: 1020), after: .school)
        swim.afterGap = 15
        let slot = F.slots(on: F.monday, items: [swim]).first { $0.title == "Swimming" }
        XCTAssertEqual(slot.map { [$0.start, $0.end] }, [915, 975])
    }

    /// No school days: an item after School keeps its weekday on a school holiday at its own time,
    /// from Home with its own trip; without a plan it is skipped.
    func testNoSchoolDaysAtASetTime() {
        var swim = linked(F.weekly("Swimming", days: [.monday], start: 960, end: 1020), after: .school)
        swim.skipsHolidays = true
        swim.noSchool = NoSchoolPlan(start: 600, trip: Trip(way: .car, leaveBefore: 15))
        let holiday = F.slots(on: F.monday, items: [swim], holidays: [F.monday]).first { $0.title == "Swimming" }
        XCTAssertEqual(holiday.map { [$0.start, $0.end] }, [600, 660])
        XCTAssertEqual(holiday?.trip?.way, .car)
        let schoolDay = F.slots(on: F.monday, items: [swim]).first { $0.title == "Swimming" }
        XCTAssertEqual(schoolDay?.start, 900, "on a school day it still follows School")
        XCTAssertNil(schoolDay?.trip)
    }

    func testChainsFollowTheItemBefore() {
        let art = linked(F.weekly("Art", days: [.monday], start: 0, end: 45), after: .school)
        let snack = linked(F.weekly("Snack", days: [.monday], start: 0, end: 15), after: .item(art.id))
        let slots = F.slots(on: F.monday, items: [snack, art])
        XCTAssertEqual(slots.first { $0.title == "Art" }.map { [$0.start, $0.end] }, [900, 945])
        XCTAssertEqual(slots.first { $0.title == "Snack" }.map { [$0.start, $0.end] }, [945, 960])
    }

    func testALinkedItemHasNoTripOfItsOwn() {
        let item = ScheduleItem(id: UUID(), title: "Art", iconName: "actArt", audience: .kid(F.kidA.id), start: 900,
                                end: 960, recurrence: .weekly([.monday], from: F.monday, until: nil), skippedDays: [],
                                skipsHolidays: true, showsStar: false, trip: Trip(way: .walk, leaveBefore: 10),
                                after: .school)
        XCTAssertNil(item.trip)
    }

    func testTripMedalDefaultsAndHomeAfter() {
        let trip = Trip(way: .bus, leaveBefore: 23, homeAfter: 27)
        XCTAssertEqual([trip.leaveBefore, trip.homeAfter], [20, 25], "steps of 5")
        XCTAssertTrue(trip.givesMedal(isSchool: true))
        XCTAssertFalse(trip.givesMedal(isSchool: false))
        XCTAssertTrue(Trip(way: .car, leaveBefore: 10, medal: true).givesMedal(isSchool: false))
    }

    func testOlderStoredValuesStillLoad() throws {
        let trip = try JSONDecoder().decode(Trip.self, from: Data(#"{"way":"bus","leaveBefore":20}"#.utf8))
        XCTAssertEqual(trip, Trip(way: .bus, leaveBefore: 20))
        let kid = UUID()
        let plan = try JSONDecoder().decode(BusPlan.self, from: Data(
            #"{"kid":"\#(kid.uuidString)","stop":"00000","services":["1"],"walk":10,"ride":10,"lateGrace":15}"#.utf8))
        XCTAssertEqual(plan.event, .school, "a route from before routes per event is School's")
        let swim = BusPlan(kid: kid, event: .item(UUID()), stop: "00001", services: ["2"])
        XCTAssertEqual([swim, plan].route(kid: kid), plan)
        XCTAssertEqual([swim, plan].route(kid: kid, event: swim.event), swim)
    }
}
