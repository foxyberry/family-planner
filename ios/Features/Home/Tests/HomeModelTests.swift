import DesignSystem
import Domain
import Foundation
import Home
import XCTest

final class HomeModelTests: XCTestCase {
    private func slot(_ title: String, _ kind: SlotKind, _ start: Int, _ end: Int,
                      source: Slot.Source = .routine) -> Slot {
        Slot(title: title, iconName: "actPlay", kind: kind, start: start, end: end, source: source, showsStar: false)
    }

    private lazy var day: [Slot] = [
        slot("Sleep", .sleep, 0, 420), slot("Breakfast", .morning, 420, 465), slot("School", .school, 480, 900),
        slot("Play", .play, 900, 930), slot("Swimming", .afterSchool, 930, 990, source: .weekly(UUID())),
        slot("Play", .play, 990, 1080), slot("Dinner", .dinner, 1080, 1140), slot("Sleep", .sleep, 1230, 1440),
    ]

    func testHubShowsCurrentSlot() {
        XCTAssertEqual(HomeModel.hub(day, minute: 945, day: "Tuesday"), PieClock.Hub(day: "Tuesday", title: "Swimming", subtitle: "until 4:30 pm"))
    }

    func testHubGapSaysFreeTimeUntilNext() {
        XCTAssertEqual(HomeModel.hub(day, minute: 470, day: "Tuesday"), PieClock.Hub(day: "Tuesday", title: "Free time", subtitle: "until 8:00 am"))
    }

    func testHubFreeTimeWithoutSecondLineWhenNothingLater() {
        let evening = [slot("Dinner", .dinner, 1080, 1140)]
        XCTAssertEqual(HomeModel.hub(evening, minute: 1200, day: "Tuesday"), PieClock.Hub(day: "Tuesday", title: "Free time", subtitle: nil))
    }

    /// A free-time slot (board A1, 16:00–17:00 on a school day): plain paper, no picture, named like a gap.
    private var freeDay: [Slot] {
        [slot("Snack", .play, 900, 960),
         Slot(title: "Free time", iconName: "", kind: .free, start: 960, end: 1020, source: .routine, showsStar: false),
         slot("Play", .play, 1020, 1110)]
    }

    func testHubSaysFreeTimeForAFreeSlot() {
        XCTAssertEqual(HomeModel.hub(freeDay, minute: 990, day: "Tuesday"), PieClock.Hub(day: "Tuesday", title: "Free time", subtitle: "until 5:00 pm"))
    }

    func testFreeSectorHasNoPicture() {
        let free = HomeModel.sectors(freeDay, minute: 990)[1]
        XCTAssertEqual(free.style, .free)
        XCTAssertNil(free.iconName)
        XCTAssertTrue(free.isCurrent)
    }

    func testNextRowsSkipFreeTime() {
        XCTAssertEqual(HomeModel.nextRows(freeDay, minute: 930).map(\.title), ["Play"])
    }

    func testEverySlotKindHasAClockStyle() {
        for kind in SlotKind.allCases {
            let sector = HomeModel.sectors([slot("Any", kind, 0, 60)], minute: 0)[0]
            XCTAssertEqual(sector.style.rawValue, kind.rawValue)
        }
    }

    func testHubNothingPlanned() {
        XCTAssertEqual(HomeModel.hub([], minute: 600, day: "Tuesday"), PieClock.Hub(day: "Tuesday", title: "Nothing planned", subtitle: nil))
    }

    func testHubSleepBeforeMidnightSaysUntilWakeUp() {
        XCTAssertEqual(HomeModel.hub(day, minute: 1380, day: "Tuesday"), PieClock.Hub(day: "Tuesday", title: "Sleep", subtitle: "until 7:00 am"))
    }

    func testSectorsMarkCurrentAndPriority() {
        let sectors = HomeModel.sectors(day, minute: 945)
        XCTAssertEqual(sectors.filter(\.isCurrent).map(\.start), [930])
        XCTAssertEqual(sectors.first { $0.start == 930 }?.priority, 1)
        XCTAssertEqual(sectors.first { $0.start == 930 }?.style, .afterSchool)
    }

    func testNextRowsAtMostTwoAfterNow() {
        XCTAssertEqual(HomeModel.nextRows(day, minute: 945).map(\.title), ["Play", "Dinner"])
        XCTAssertEqual(HomeModel.nextRows(day, minute: 1235).map(\.title), [])
    }

    func testNextItemSkipsRoutine() {
        XCTAssertEqual(HomeModel.nextItem(day, minute: 600)?.title, "Swimming")
        XCTAssertNil(HomeModel.nextItem(day, minute: 1000))
    }

    func testUntilIsTwelveHourWithAmPm() {
        let morning = [slot("School", .school, 450, 720), slot("Lunch", .play, 720, 780)]
        XCTAssertEqual(HomeModel.hub(morning, minute: 600, day: "Tuesday").subtitle, "until 12:00 pm")
        XCTAssertEqual(HomeModel.hub([slot("Late", .event, 1200, 1440)], minute: 1300, day: "Tuesday").subtitle,
                       "until 12:00 am")
    }

    func testAccessibilityLabel() {
        XCTAssertEqual(HomeModel.accessibilityLabel(kidName: "Kid A", day: "Tuesday", slots: day, minute: 945),
                       "Kid A's day as a 24-hour clock. Midnight at the top, noon at the bottom. Tuesday 3:45, Swimming.")
        XCTAssertEqual(HomeModel.accessibilityLabel(kidName: "Kid A", day: "Tuesday", slots: day, minute: 470),
                       "Kid A's day as a 24-hour clock. Midnight at the top, noon at the bottom. Tuesday 7:50, Free time.")
    }
}
