import Domain
import Foundation
import Home
import XCTest

/// Spec A1 "Next things" (layout v81): the family's next things in time order.
final class HomeNextTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return calendar
    }()
    private let tuesday = Day(year: 2026, month: 11, day: 10)
    private let kidA = UUID(), kidB = UUID()

    private func slot(_ title: String, _ kind: SlotKind, _ start: Int, _ end: Int, source: Slot.Source = .routine,
                      trip: Trip? = nil) -> Slot {
        Slot(title: title, iconName: "actPlay", kind: kind, start: start, end: end, source: source, showsStar: false,
             trip: trip)
    }

    private func day(_ kid: UUID, _ today: [Slot], tomorrow: [Slot] = [], mission: Slot? = nil) -> HomeNext.KidDay {
        HomeNext.KidDay(kid: kid, today: today, tomorrow: tomorrow, ahead: nil, missionOutings: mission.map { [$0] } ?? [])
    }

    /// Two kids' things, nearest first; free time and what is on now are left out; an outing's time is
    /// its leave time.
    func testTimeOrderWithLeaveTimes() {
        let school = slot("School", .school, 900, 960, trip: Trip(way: .bus, leaveBefore: 20))
        let things = HomeNext.things([
            day(kidA, [slot("Play", .play, 600, 700), slot("", .free, 700, 800), school]),
            day(kidB, [slot("Snack", .play, 870, 890)]),
        ], minute: 650, today: tuesday, calendar: calendar)
        XCTAssertEqual(things.map(\.title), ["Snack", "School"])
        XCTAssertEqual(things.map(\.act), [870, 880], "School: 900 − 20")
    }

    /// The same thing at the same time is one row with both faces; the same name at another time is not.
    func testTheSameThingIsOneRow() {
        let item = UUID()
        let things = HomeNext.things([
            day(kidA, [slot("Dinner", .dinner, 1080, 1140), slot("Party", .event, 900, 960, source: .once(item))]),
            day(kidB, [slot("Dinner", .dinner, 1080, 1140), slot("Party", .event, 900, 960, source: .once(item)),
                       slot("Dinner", .dinner, 1100, 1140)]),
        ], minute: 600, today: tuesday, calendar: calendar)
        XCTAssertEqual(things.map(\.title), ["Party", "Dinner", "Dinner"])
        XCTAssertEqual(things[0].kids, [kidA, kidB])
        XCTAssertEqual(things[1].kids, [kidA, kidB])
        XCTAssertEqual(things[2].kids, [kidB])
    }

    /// Spec A1 "Moments" (board A1p): an event whose way home is pickup adds a grown-up row at end −
    /// homeAfter, titled with the event's name, with the pickup picture; never a mission row. Two kids
    /// on the same event share it; it leaves when its time passes, even while the event is on.
    func testAPickupRowAtEndMinusHomeAfter() {
        let item = UUID()
        var swim = slot("Swimming", .afterSchool, 930, 990, source: .weekly(item), trip: Trip(way: .car, leaveBefore: 15))
        swim.lists = EventLists(wayHome: .pickup, homeAfter: 20)
        let things = HomeNext.things([day(kidA, [swim]), day(kidB, [swim])], minute: 600, today: tuesday,
                                     calendar: calendar)
        XCTAssertEqual(things.map(\.title), ["Swimming", "Swimming"])
        XCTAssertEqual(things.map(\.act), [915, 970], "leave 930 − 15; pickup 990 − 20")
        XCTAssertEqual(things[1].iconName, "pickup")
        XCTAssertTrue(things[1].isPickup)
        XCTAssertFalse(things[1].isMission)
        XCTAssertEqual(things[1].kids, [kidA, kidB])
        XCTAssertFalse(things[0].isPickup)

        let during = HomeNext.things([day(kidA, [swim])], minute: 950, today: tuesday, calendar: calendar)
        XCTAssertEqual(during.map(\.isPickup), [true], "the event is on; its pickup is still ahead")
        XCTAssertEqual(HomeNext.things([day(kidA, [swim])], minute: 975, today: tuesday, calendar: calendar), [],
                       "past the pickup time")
    }

    /// The pickup belongs to the chain's last event: a pickup set on an event that another follows
    /// makes no row, and the follower's own pickup does.
    func testAPickupOnlyAtTheChainsEnd() {
        let schoolID = UUID(), swimID = UUID()
        var school = slot("School", .school, 480, 900, source: .weekly(schoolID), trip: Trip(way: .bus, leaveBefore: 30))
        school.lists = EventLists(wayHome: .pickup, homeAfter: 20)
        var swim = slot("Swimming", .afterSchool, 900, 960, source: .weekly(swimID))
        swim.after = .item(schoolID)
        let none = HomeNext.things([day(kidA, [school, swim])], minute: 400, today: tuesday, calendar: calendar)
        XCTAssertFalse(none.contains { $0.isPickup })
        swim.lists = EventLists(wayHome: .pickup, homeAfter: 15)
        let one = HomeNext.things([day(kidA, [school, swim])], minute: 400, today: tuesday, calendar: calendar)
        XCTAssertEqual(one.filter(\.isPickup).map(\.act), [945])
        XCTAssertEqual(one.filter(\.isPickup).map(\.title), ["Swimming"])
    }

    /// A template slot that only resumes after an item is left out.
    func testASlotThatOnlyResumesIsLeftOut() {
        let things = HomeNext.things([
            day(kidA, [slot("Play", .play, 700, 800), slot("Art", .afterSchool, 800, 860, source: .weekly(UUID())),
                       slot("Play", .play, 860, 900)]),
        ], minute: 600, today: tuesday, calendar: calendar)
        XCTAssertEqual(things.map(\.title), ["Play", "Art"])
    }

    /// Asleep for the night, or nothing left today: tomorrow's first things after wake-up.
    func testAfterBedtimeTheNextDaysFirstThings() {
        let tomorrow = [slot("Sleep", .sleep, 0, 420), slot("Breakfast", .morning, 420, 450), slot("School", .school, 450, 900)]
        let things = HomeNext.things([
            day(kidA, [slot("Dinner", .dinner, 1080, 1230), slot("Sleep", .sleep, 1230, 1440)], tomorrow: tomorrow),
        ], minute: 1300, today: tuesday, calendar: calendar)
        XCTAssertEqual(things.map(\.title), ["Breakfast", "School"])
        XCTAssertEqual(things.map(\.inDays), [1, 1])
        XCTAssertEqual(things.first?.weekday, .wednesday)
    }

    /// An afternoon nap is not the night: during it, today's later things stay (#282 review).
    func testANapKeepsTodaysThings() {
        let things = HomeNext.things([
            day(kidB, [slot("Nap", .sleep, 780, 900), slot("Snack", .play, 900, 930), slot("Sleep", .sleep, 1230, 1440)],
                tomorrow: [slot("Sleep", .sleep, 0, 420), slot("Breakfast", .morning, 420, 450)]),
        ], minute: 840, today: tuesday, calendar: calendar)
        XCTAssertEqual(things.first?.title, "Snack")
        XCTAssertEqual(things.first?.inDays, 0)
    }

    /// Spec A1 "Mission rows": an outing with something to check is a mission row for that kid.
    func testTheMissionOutingIsMarked() {
        let school = slot("School", .school, 450, 900, trip: Trip(way: .bus, leaveBefore: 5))
        let things = HomeNext.things([day(kidA, [school], mission: school), day(kidB, [slot("Play", .play, 500, 600)])],
                                     minute: 400, today: tuesday, calendar: calendar)
        XCTAssertEqual(things.first { $0.title == "School" }?.missionKids, [kidA])
        XCTAssertEqual(things.first { $0.title == "Play" }?.isMission, false)
    }
}
