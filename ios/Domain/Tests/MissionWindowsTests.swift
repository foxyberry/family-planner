import Domain
import XCTest

/// Spec "Events: one shape", Mission windows: the day's stretches for missions, from wake, each
/// outing's leave and home, dinner and bed.
final class MissionWindowsTests: XCTestCase {
    private let art = UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!
    private let swim = UUID(uuidString: "00000000-0000-0000-0000-00000000A002")!
    private let party = UUID(uuidString: "00000000-0000-0000-0000-00000000A003")!
    private let night = NightSpan(start: 1110, wake: 390)

    private func slot(_ kind: SlotKind, _ start: Int, _ end: Int, source: Slot.Source = .routine,
                      trip: Trip? = nil, after: EventRef? = nil) -> Slot {
        Slot(title: "\(kind)", iconName: "actPlay", kind: kind, start: start, end: end, source: source,
             showsStar: false, trip: trip, after: after)
    }

    private func schoolDay(extra: [Slot] = []) -> [Slot] {
        ([slot(.sleep, 0, 390), slot(.morning, 390, 450),
          slot(.school, 450, 810, trip: Trip(way: .bus, leaveBefore: 25, homeAfter: 20)),
          slot(.free, 810, 1080), slot(.dinner, 1080, 1110), slot(.evening, 1110, 1200),
          slot(.sleep, 1200, 1440)] + extra).sorted { $0.start < $1.start }
    }

    func testSchoolMorningRunsFromWakeToLeaveAndHoldsTheBeforeSchoolMissions() {
        let spans = DayPlanner.missionWindows(slots: schoolDay(), night: night)
        let morning = spans.first
        XCTAssertEqual(morning?.start, 390)
        XCTAssertEqual(morning?.end, 425)
        XCTAssertEqual(morning?.parts, [.morning, .before(.school)])
        XCTAssertEqual(morning?.outing?.slot.kind, .school)
    }

    func testAfterSchoolRunsFromHomeToDinnerAndCoversTheLinkedChain() {
        var slots = schoolDay()
        slots.removeAll { $0.kind == .free }
        slots.append(slot(.event, 810, 855, source: .weekly(art), after: .school))
        slots.append(slot(.free, 855, 1080))
        let spans = DayPlanner.missionWindows(slots: slots.sorted { $0.start < $1.start }, night: night)
        let after = spans.first { $0.parts.first == .after(.school) }
        XCTAssertEqual(after?.start, 875, "art ends at 855, then 20 min home")
        XCTAssertEqual(after?.end, 1080)
        XCTAssertEqual(after?.parts, [.after(.school), .after(.item(art))])
    }

    func testASecondOutingMakesTheAfterSchoolStretchEndAtItsLeave() {
        let swimming = slot(.event, 960, 1020, source: .weekly(swim),
                            trip: Trip(way: .walk, leaveBefore: 10, homeAfter: 15))
        var slots = schoolDay()
        slots.removeAll { $0.kind == .free }
        slots += [slot(.free, 810, 960), swimming, slot(.free, 1020, 1080)]
        let spans = DayPlanner.missionWindows(slots: slots.sorted { $0.start < $1.start }, night: night)
        let between = spans.first { $0.start == 830 }
        XCTAssertEqual(between?.end, 950)
        XCTAssertEqual(between?.parts, [.after(.school), .before(.item(swim))])
        XCTAssertEqual(between?.outing?.slot.source, .weekly(swim))
        let afterSwim = spans.first { $0.parts == [.after(.item(swim))] }
        XCTAssertEqual(afterSwim?.start, 1035)
        XCTAssertEqual(afterSwim?.end, 1080)
    }

    func testADayWithoutAnOutingKeepsTheMorningUntilNoon() {
        let slots = [slot(.sleep, 0, 450), slot(.play, 450, 1080), slot(.dinner, 1080, 1110),
                     slot(.evening, 1110, 1200), slot(.sleep, 1200, 1440)]
        let spans = DayPlanner.missionWindows(slots: slots, night: NightSpan(start: 1110, wake: 450))
        XCTAssertEqual(spans.first?.parts, [.morning])
        XCTAssertEqual(spans.first?.end, 720)
        XCTAssertNil(spans.first?.outing)
    }

    func testAnAfternoonOutingGetsItsOwnBeforeStretchFromNoon() {
        let outing = slot(.event, 840, 960, source: .once(party), trip: Trip(way: .car, leaveBefore: 15))
        let slots = [slot(.sleep, 0, 450), slot(.play, 450, 840), outing, slot(.play, 960, 1080),
                     slot(.dinner, 1080, 1110), slot(.evening, 1110, 1200), slot(.sleep, 1200, 1440)]
        let spans = DayPlanner.missionWindows(slots: slots, night: NightSpan(start: 1110, wake: 450))
        XCTAssertEqual(spans.map(\.parts), [[.morning], [.before(.item(party))], [.after(.item(party))], [.evening]])
        XCTAssertEqual(spans[1].start, 720)
        XCTAssertEqual(spans[1].end, 825)
        XCTAssertEqual(spans[2].start, 960)
    }

    func testEveningRunsFromDinnerToBed() {
        let evening = DayPlanner.missionWindows(slots: schoolDay(), night: night).last
        XCTAssertEqual(evening?.parts, [.evening])
        XCTAssertEqual(evening?.start, 1080)
        XCTAssertEqual(evening?.end, 1200)
    }

    func testTheOpenWindowIsTheStretchAroundTheMinute() {
        let spans = DayPlanner.missionWindows(slots: schoolDay(), night: night)
        XCTAssertEqual(DayPlanner.window(at: 400, in: spans)?.parts.first, .morning)
        XCTAssertNil(DayPlanner.window(at: 425, in: spans), "the kid has left")
        XCTAssertNil(DayPlanner.window(at: 380, in: spans), "still asleep")
        XCTAssertEqual(DayPlanner.window(at: 900, in: spans)?.parts.first, .after(.school))
    }

    func testNoWakeMeansNoWindows() {
        XCTAssertEqual(DayPlanner.missionWindows(slots: schoolDay(), night: nil), [])
    }
}
