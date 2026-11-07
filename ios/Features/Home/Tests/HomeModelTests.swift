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
        XCTAssertEqual(HomeModel.hub(day, minute: 945), PieClock.Hub(title: "Swimming", subtitle: "until 4:30"))
    }

    func testHubGapSaysFreeTimeUntilNext() {
        XCTAssertEqual(HomeModel.hub(day, minute: 470), PieClock.Hub(title: "Free time", subtitle: "until 8:00"))
    }

    func testHubFreeTimeWithoutSecondLineWhenNothingLater() {
        let evening = [slot("Dinner", .dinner, 1080, 1140)]
        XCTAssertEqual(HomeModel.hub(evening, minute: 1200), PieClock.Hub(title: "Free time", subtitle: nil))
    }

    func testHubNothingPlanned() {
        XCTAssertEqual(HomeModel.hub([], minute: 600), PieClock.Hub(title: "Nothing planned", subtitle: nil))
    }

    func testHubSleepBeforeMidnightSaysUntilWakeUp() {
        XCTAssertEqual(HomeModel.hub(day, minute: 1380), PieClock.Hub(title: "Sleep", subtitle: "until 7:00"))
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

    func testAccessibilityLabel() {
        XCTAssertEqual(HomeModel.accessibilityLabel(kidName: "Kid A", slots: day, minute: 945),
                       "Kid A's day as a 24-hour clock. Midnight at the top, noon at the bottom. Now 3:45, Swimming.")
        XCTAssertEqual(HomeModel.accessibilityLabel(kidName: "Kid A", slots: day, minute: 470),
                       "Kid A's day as a 24-hour clock. Midnight at the top, noon at the bottom. Now 7:50, Free time.")
    }
}
