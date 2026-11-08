import DesignSystem
import XCTest

final class PieClockLayoutTests: XCTestCase {
    private func sector(_ start: Int, _ end: Int, _ style: ClockSlotStyle = .play, icon: String? = "actPlay",
                        priority: Int = 0) -> ClockSector {
        ClockSector(start: start, end: end, style: style, iconName: icon, isCurrent: false, showsStar: false,
                    priority: priority)
    }

    func testAngles() {
        XCTAssertEqual(PieClockLayout.degrees(minute: 0), 0)
        XCTAssertEqual(PieClockLayout.degrees(minute: 360), 90)
        XCTAssertEqual(PieClockLayout.degrees(minute: 720), 180)
        XCTAssertEqual(PieClockLayout.degrees(minute: 1080), 270)
    }

    func testMidnightSleepMerges() {
        let drawn = PieClockLayout.drawable([sector(0, 420, .sleep), sector(420, 1230), sector(1230, 1440, .sleep)])
        XCTAssertEqual(drawn.count, 2)
        let sleep = drawn.first { $0.style == .sleep }
        XCTAssertEqual(sleep?.start, 1230)
        XCTAssertEqual(sleep?.end, 1440 + 420)
    }

    func testCurrentFlagSurvivesMerge() {
        var late = sector(1230, 1440, .sleep)
        late.isCurrent = true
        let sleep = PieClockLayout.drawable([sector(0, 420, .sleep), late]).first { $0.style == .sleep }
        XCTAssertEqual(sleep?.isCurrent, true)
    }

    func testShortSlotsGetMinimumWidthAndPushApart() {
        let drawn = PieClockLayout.drawable([sector(600, 605, .event), sector(605, 610, .afterSchool)])
        XCTAssertEqual(drawn.map(\.style), [.event, .afterSchool])
        for s in drawn { XCTAssertGreaterThanOrEqual(s.end - s.start, 10) }
        XCTAssertLessThanOrEqual(drawn[0].end, drawn[1].start)
        XCTAssertNil(drawn[0].iconName, "short slots show no picture")
    }

    func testCollidingShortSlotDropsLowerPriority() {
        let drawn = PieClockLayout.drawable([sector(600, 601, .play, priority: 0), sector(601, 602, .event, priority: 2),
                                             sector(602, 603, .afterSchool, priority: 1)])
        XCTAssertTrue(drawn.contains { $0.style == .event })
        for i in drawn.indices.dropFirst() { XCTAssertLessThanOrEqual(drawn[i - 1].end, drawn[i].start) }
    }

    func testPictureSizeByLength() {
        XCTAssertEqual(PieClockLayout.pictureSize(minutes: 180), 104)
        XCTAssertEqual(PieClockLayout.pictureSize(minutes: 179), 84)
        XCTAssertEqual(PieClockLayout.pictureSize(minutes: 60), 84)
        XCTAssertEqual(PieClockLayout.pictureSize(minutes: 30), 68)
        XCTAssertNil(PieClockLayout.pictureSize(minutes: 29))
    }

    func testPictureMustFitItsWedge() {
        // 30 min is 7.5°: too thin for any picture even at the rim.
        XCTAssertNil(PieClockLayout.picture(minutes: 30, radius: 372, hub: 152))
        // 1 hour (15°) holds the 84 picture only out near the rim.
        let hour = PieClockLayout.picture(minutes: 60, radius: 372, hub: 152)
        XCTAssertEqual(hour?.size, 84)
        XCTAssertGreaterThan(hour?.distance ?? 0, 372 * 0.7)
        // 3 hours keeps the full size at 0.7 R.
        let long = PieClockLayout.picture(minutes: 180, radius: 372, hub: 152)
        XCTAssertEqual(long?.size, 104)
        XCTAssertEqual(long?.distance ?? 0, 372 * 0.7, accuracy: 0.5)
    }

    func testHubTitleCandidatesCutAtWords() {
        XCTAssertEqual(PieClock.hubTitleCandidates("Swimming with the class"),
                       ["Swimming with the class", "Swimming with the…", "Swimming with…", "Swimming…"])
        XCTAssertEqual(PieClock.hubTitleCandidates("Breakfast"), ["Breakfast"])
    }

    func testEveryStyleButFreeHasAFill() {
        XCTAssertEqual(ClockSlotStyle.allCases.count, 9)
        for style in ClockSlotStyle.allCases where style != .free {
            XCTAssertNotNil(style.fill?.hachure, "\(style)")
        }
        XCTAssertNil(ClockSlotStyle.free.fill, "free time is plain paper")
    }
}
