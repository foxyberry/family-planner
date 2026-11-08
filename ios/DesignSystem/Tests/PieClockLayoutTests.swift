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
        XCTAssertEqual(PieClockLayout.pictureSize(minutes: 59), 56)
        XCTAssertEqual(PieClockLayout.pictureSize(minutes: 30), 56)
        XCTAssertNil(PieClockLayout.pictureSize(minutes: 29))
    }

    /// Board A1 (2026-11-08): 104 and 84 at 0.68 R, 56 at 0.8 R where the slice is wider.
    func testPictureDistanceBySize() {
        let long = PieClockLayout.picture(minutes: 180, radius: 372, hub: 152)
        XCTAssertEqual(long?.size, 104)
        XCTAssertEqual(long?.distance ?? 0, 372 * 0.68, accuracy: 0.5)
        let hour = PieClockLayout.picture(minutes: 60, radius: 372, hub: 152)
        XCTAssertEqual(hour?.size, 84)
        XCTAssertEqual(hour?.distance ?? 0, 372 * 0.68, accuracy: 0.5)
        let short = PieClockLayout.picture(minutes: 45, radius: 372, hub: 152)
        XCTAssertEqual(short?.size, 56)
        XCTAssertEqual(short?.distance ?? 0, 372 * 0.8, accuracy: 0.5)
        XCTAssertNil(PieClockLayout.picture(minutes: 20, radius: 372, hub: 152))
    }

    func testPictureStaysBetweenHubAndRim() {
        // A smaller clock: 0.68 R (204) would push the 104 picture into the hub, so it moves out to 220.
        XCTAssertEqual(PieClockLayout.picture(minutes: 240, radius: 300, hub: 160)?.distance, 220)
        // No room between hub and rim at all: no picture.
        XCTAssertNil(PieClockLayout.picture(minutes: 240, radius: 200, hub: 120))
    }

    func testHubTitleStepsDownWhenTooWide() {
        XCTAssertEqual(PieClock.hubTitleLines("Breakfast").lines, ["Breakfast"])
        XCTAssertTrue(PieClock.hubTitleLines("Breakfast").isTitle)
        // Board E3: "Weekend school" drops to head 36 on two lines.
        XCTAssertEqual(PieClock.hubTitleLines("Weekend school").lines, ["Weekend", "school"])
        XCTAssertFalse(PieClock.hubTitleLines("Weekend school").isTitle)
        XCTAssertEqual(PieClock.hubTitleLines("Swimming with the whole class").lines.count, 2)
    }

    func testEveryStyleButFreeHasAFill() {
        XCTAssertEqual(ClockSlotStyle.allCases.count, 9)
        for style in ClockSlotStyle.allCases where style != .free {
            XCTAssertNotNil(style.fill?.hachure, "\(style)")
        }
        XCTAssertNil(ClockSlotStyle.free.fill, "free time is plain paper")
    }
}
