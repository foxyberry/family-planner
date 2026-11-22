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
        XCTAssertEqual(HomeModel.hub(day, minute: 945), PieClock.Hub(title: "Swimming", subtitle: "until 4:30 pm"))
    }

    func testHubGapSaysFreeTimeUntilNext() {
        XCTAssertEqual(HomeModel.hub(day, minute: 470), PieClock.Hub(title: "Free time", subtitle: "until 8:00 am"))
    }

    func testHubFreeTimeWithoutSecondLineWhenNothingLater() {
        let evening = [slot("Dinner", .dinner, 1080, 1140)]
        XCTAssertEqual(HomeModel.hub(evening, minute: 1200), PieClock.Hub(title: "Free time", subtitle: nil))
    }

    /// A free-time slot (board A1, 16:00–17:00 on a school day): plain paper, no picture, named like a gap.
    private var freeDay: [Slot] {
        [slot("Snack", .play, 900, 960),
         Slot(title: "Free time", iconName: "", kind: .free, start: 960, end: 1020, source: .routine, showsStar: false),
         slot("Play", .play, 1020, 1110)]
    }

    func testHubSaysFreeTimeForAFreeSlot() {
        XCTAssertEqual(HomeModel.hub(freeDay, minute: 990), PieClock.Hub(title: "Free time", subtitle: "until 5:00 pm"))
    }

    func testFreeSectorHasNoPicture() {
        let free = HomeModel.sectors(freeDay, minute: 990)[1]
        XCTAssertEqual(free.style, .free)
        XCTAssertNil(free.iconName)
        XCTAssertTrue(free.isCurrent)
    }

    func testEverySlotKindHasAClockStyle() {
        for kind in SlotKind.allCases {
            let sector = HomeModel.sectors([slot("Any", kind, 0, 60)], minute: 0)[0]
            XCTAssertEqual(sector.style.rawValue, kind.rawValue)
        }
    }

    func testHubNothingPlanned() {
        XCTAssertEqual(HomeModel.hub([], minute: 600), PieClock.Hub(title: "Nothing planned", subtitle: nil))
    }

    func testHubSleepBeforeMidnightSaysUntilWakeUp() {
        XCTAssertEqual(HomeModel.hub(day, minute: 1380), PieClock.Hub(title: "Sleep", subtitle: "until 7:00 am"))
    }

    func testSectorsMarkCurrentAndPriority() {
        let sectors = HomeModel.sectors(day, minute: 945)
        XCTAssertEqual(sectors.filter(\.isCurrent).map(\.start), [930])
        XCTAssertEqual(sectors.first { $0.start == 930 }?.priority, 1)
        XCTAssertEqual(sectors.first { $0.start == 930 }?.style, .afterSchool)
    }

    func testUntilIsTwelveHourWithAmPm() {
        let morning = [slot("School", .school, 450, 720), slot("Lunch", .play, 720, 780)]
        XCTAssertEqual(HomeModel.hub(morning, minute: 600).subtitle, "until 12:00 pm")
        XCTAssertEqual(HomeModel.hub([slot("Late", .event, 1200, 1440)], minute: 1300).subtitle,
                       "until 12:00 am")
    }

    // MARK: Now and next on home (one rule, 2026-11-08)

    func testNextSkipsFreeTime() {
        XCTAssertEqual(HomeModel.next(freeDay, minute: 930)?.title, "Play")
    }

    func testNextIsOneThingOfAnyKind() {
        XCTAssertEqual(HomeModel.next(day, minute: 600)?.title, "Play")       // a template slot
        XCTAssertEqual(HomeModel.next(day, minute: 905)?.title, "Swimming")   // an every-week item
        XCTAssertEqual(HomeModel.next(day, minute: 600)?.line, "at 3:00 pm")
    }

    func testNextSkipsASlotThatOnlyContinuesAfterAnItem() {
        // During Swimming the rest of Play only resumes, so Next is Dinner.
        XCTAssertEqual(HomeModel.next(day, minute: 945)?.title, "Dinner")
        // Board E3 at 9:15: Weekend school, then Play resumes, then the Birthday.
        let saturday = [
            slot("Sleep", .sleep, 0, 450), slot("Breakfast", .morning, 450, 510), slot("Play", .play, 510, 540),
            slot("Weekend school", .afterSchool, 540, 720, source: .weekly(UUID())), slot("Play", .play, 720, 840),
            slot("Birthday", .event, 840, 960, source: .once(UUID())), slot("Play", .play, 960, 1140),
            slot("Dinner", .dinner, 1140, 1215),
        ]
        XCTAssertEqual(HomeModel.next(saturday, minute: 555)?.title, "Birthday")
        XCTAssertEqual(HomeModel.next(saturday, minute: 555)?.line, "at 2:00 pm")
        XCTAssertEqual(HomeModel.next(saturday, minute: 900)?.title, "Dinner")
    }

    func testNothingNextLateAtNight() {
        XCTAssertNil(HomeModel.next(day, minute: 1235))
    }

    /// Spec "The row" (user, 2026-11-22): "in {n} min" while the start is 60 minutes or less away,
    /// else the time of day; never "1h 20m" on a Next row.
    func testNextLineSaysInMinutesUpToAnHour() {
        XCTAssertEqual(HomeModel.next(day, minute: 840)?.line, "in 60 min")    // Play at 3:00 pm
        XCTAssertEqual(HomeModel.next(day, minute: 839)?.line, "at 3:00 pm")   // 61 minutes away
        XCTAssertEqual(HomeModel.next(day, minute: 862)?.line, "in 38 min")    // board E1
        XCTAssertEqual(HomeModel.next(day, minute: 899)?.line, "in 1 min")
        XCTAssertEqual(HomeModel.nextLine(start: 900, minutesAway: 60), "in 60 min")
        XCTAssertEqual(HomeModel.nextLine(start: 900, minutesAway: 61), "at 3:00 pm")
        XCTAssertEqual(HomeModel.nextLine(start: 900, minutesAway: 80), "at 3:00 pm")
    }

    /// Board A1n: Kid B asleep from 7:30 pm; Next goes on to tomorrow's first thing after waking.
    func testNextAtNightGoesOnToTomorrowAfterWakeUp() {
        let tomorrow = [slot("Sleep", .sleep, 0, 390), slot("Breakfast", .morning, 390, 450), slot("School", .school, 480, 900)]
        let tonight = [slot("Dinner", .dinner, 1080, 1140), slot("Sleep", .sleep, 1170, 1440)]
        let next = HomeModel.next(tonight, minute: 1180, tomorrow: tomorrow)
        XCTAssertEqual(next?.title, "Breakfast")
        XCTAssertEqual(next?.line, "at 6:30 am")
        // 45 minutes away across midnight still counts down.
        XCTAssertEqual(HomeModel.next(tonight, minute: 1425, tomorrow: [slot("Sleep", .sleep, 0, 30), slot("Milk", .morning, 30, 60)])?.line,
                       "in 45 min")
        // Without tomorrow's day (Kid A) nothing is next once Sleep has started.
        XCTAssertNil(HomeModel.next(tonight, minute: 1180))
    }

    /// Kid B's Now row: the slot "until" its end; free time or a gap is "Free time" with play.
    func testNowRowSaysUntilTheEnd() {
        XCTAssertEqual(HomeModel.now(day, minute: 945),
                       NowItem(picture: .actPlay, title: "Swimming", line: "until 4:30 pm", showsStar: false))
        XCTAssertEqual(HomeModel.now(day, minute: 1300).line, "until 7:00 am")   // Sleep runs on to wake-up
        XCTAssertEqual(HomeModel.now(day, minute: 470),
                       NowItem(picture: .actPlay, title: "Free time", line: "until 8:00 am", showsStar: false))
        XCTAssertEqual(HomeModel.now(freeDay, minute: 990).line, "until 5:00 pm")
        XCTAssertEqual(HomeModel.now([], minute: 600),
                       NowItem(picture: .actPlay, title: "Free time", line: nil, showsStar: false))
    }

    func testBedInOnlyBeforeSleep() {
        // At night Next is Sleep: "Bed in".
        XCTAssertEqual(HomeModel.bedIn(to: HomeModel.next(day, minute: 1150), minute: 1150),
                       HomeModel.TimeLeft(label: "Bed in", minutes: 80))
        // By day there is no time left block: the Next row says "in 38 min" itself.
        XCTAssertNil(HomeModel.bedIn(to: HomeModel.next(day, minute: 862), minute: 862))
        // Over 3 hours: no time left.
        let late = [slot("Play", .play, 600, 900), slot("Sleep", .sleep, 1230, 1440)]
        XCTAssertNil(HomeModel.bedIn(to: HomeModel.next(late, minute: 960), minute: 960))
    }

    /// The time left part shows what this model says.
    func testTimeLeftWords() {
        let soon = HomeModel.TimeLeft(label: "Bed in", minutes: 80)
        XCTAssertEqual(soon.text, "1h 20m")
        XCTAssertFalse(soon.isLate)
        let late = HomeModel.TimeLeft(label: "Leave in", minutes: -2)
        XCTAssertEqual(late.text, "\u{2212}2 min")
        XCTAssertTrue(late.isLate)
    }
}
