import Domain
import XCTest

/// Spec "A2 live look" maths. Made-up stop and bus numbers only (privacy rule).
final class LiveBusTests: XCTestCase {
    private let plan = BusPlan(kid: UUID(uuidString: "5EED0000-0000-4000-8000-0000000000A1")!, stop: "00000",
                               services: ["1", "2"], walk: 10, ride: 10, lateGrace: 15)
    private let start = 450 // 7:30 am

    private func bus(_ service: String, _ minutes: Int) -> BusArrival {
        BusArrival(service: service, minutes: minutes, type: .double)
    }

    func testChosenIsTheFirstBusTheKidCanWalkTo() {
        // 6:52 am: bus 1 in 4 min (too soon), bus 2 in 28 min (there 7:30), bus 9 is not ours.
        let live = LiveMorning(arrivals: [bus("9", 2), bus("1", 4), bus("2", 28), bus("1", 40)], plan: plan,
                               minute: 412, start: start)
        XCTAssertEqual(live.shown.map(\.minutes), [4, 28])
        XCTAssertEqual(live.chosen, bus("2", 28))
        XCTAssertEqual(live.tooSoon, bus("1", 4))
        XCTAssertEqual(live.leaveIn, 18)
        XCTAssertEqual(live.status, .onTime)
    }

    func testLeaveNowAtZero() {
        let live = LiveMorning(arrivals: [bus("1", 10)], plan: plan, minute: 420, start: start)
        XCTAssertEqual(live.leaveIn, 0)
        XCTAssertEqual(live.status, .leaveNow)
    }

    func testAskAGrownupWhenNoBusGetsThereInTime() {
        // 7:20 am: the next bus in 30 min arrives 8:00, past 7:30 + 15.
        let live = LiveMorning(arrivals: [bus("1", 30)], plan: plan, minute: 440, start: start)
        XCTAssertEqual(live.status, .askGrownup)
        XCTAssertEqual(LiveMorning(arrivals: [], plan: plan, minute: 412, start: start).status, .askGrownup)
    }

    func testBetweenStartAndLateGraceHasNoStatusWord() {
        // Arrives 7:38: after the start, inside the grace; no "On time", no late word.
        let live = LiveMorning(arrivals: [bus("1", 18)], plan: plan, minute: 430, start: start)
        XCTAssertNil(live.status)
    }

    func testMedalsFromTheTimeOnly() throws {
        // Buses at 7:06, 7:13, 7:21 (minute 412 + 14/21/29); ride 10: by 7:30 the 7:13 one (leave 7:03),
        // by 7:45 the 7:21 one (leave 7:11).
        let targets = try XCTUnwrap(LiveMorning.leaveTargets(arrivals: [bus("1", 14), bus("2", 21), bus("1", 29)],
                                                             plan: plan, minute: 412, start: start))
        XCTAssertEqual(targets.ideal, 423)
        XCTAssertEqual(targets.latest, 431)
        XCTAssertEqual(LiveMorning.medal(readyAt: 418, ideal: 423, latest: 431), .gold)
        XCTAssertEqual(LiveMorning.medal(readyAt: 423, ideal: 423, latest: 431), .silver)
        XCTAssertEqual(LiveMorning.medal(readyAt: 431, ideal: 423, latest: 431), .bronze)
        XCTAssertEqual(LiveMorning.medal(readyAt: 432, ideal: 423, latest: 431), MorningMedal.none)
    }

    func testTimetableFallbackTargets() {
        let targets = LiveMorning.timetableTargets(start: start, leaveBefore: 5)
        XCTAssertEqual(targets.ideal, 445)
        XCTAssertEqual(targets.latest, 460)
    }
}
