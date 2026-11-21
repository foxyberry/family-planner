import Domain
import XCTest

/// Spec "A2 live look" maths. Made-up stop and bus numbers only (privacy rule).
final class LiveBusTests: XCTestCase {
    private let plan = BusPlan(kid: UUID(uuidString: "5EED0000-0000-4000-8000-0000000000A1")!, stop: "00000",
                               services: ["1"], walk: 10, ride: 10, lateGrace: 15)
    private let start = 450 // 7:30 am

    private func bus(_ service: String, _ minutes: Int) -> BusArrival {
        BusArrival(service: service, minutes: minutes, type: .double)
    }

    func testChosenIsTheFirstBusTheKidCanWalkTo() {
        // 6:52 am: bus 1 in 4 min (too soon), again in 28 min (there 7:30), bus 9 is not ours.
        let live = LiveMorning(arrivals: [bus("9", 2), bus("1", 4), bus("1", 28), bus("1", 40)], plan: plan,
                               minute: 412, start: start)
        XCTAssertEqual(live.buses.map(\.arrival.minutes), [4, 28], "under 30 min, ours only")
        XCTAssertEqual(live.chosen?.arrival, bus("1", 28))
        XCTAssertEqual(live.others.map(\.isCatchable), [false], "the 4-min bus is too soon")
        XCTAssertEqual(live.leaveIn, 18)
        XCTAssertEqual(live.status, .onTime)
    }

    /// Spec "Several buses": every bus is equal; the catchable one that reaches the place first is
    /// chosen, whatever its order, with each bus's own ride.
    func testTheBusThatGetsThereFirstIsChosen() {
        var both = plan
        both.services = ["1", "2"]
        both.rides = ["2": 25]
        // Bus 2 in 12 min reaches in 37; bus 1 in 20 reaches in 30: bus 1 wins though it comes later.
        let live = LiveMorning(arrivals: [bus("2", 5), bus("2", 12), bus("1", 20)], plan: both, minute: 400,
                               start: start)
        XCTAssertEqual(live.chosen?.arrival, bus("1", 20))
        XCTAssertEqual(live.leaveIn, 10)
        XCTAssertEqual(live.others.map(\.arrival), [bus("2", 5), bus("2", 12)])
        // A tie at the place goes to the bus at our stop first.
        both.rides = ["2": 18]
        XCTAssertEqual(LiveMorning(arrivals: [bus("1", 20), bus("2", 12)], plan: both, minute: 400, start: start)
            .chosen?.arrival, bus("2", 12))
    }

    /// Spec "C2c": the bus that changes takes Ride 1 + Change + Ride 2; a bus that is also a direct
    /// bus goes the faster way.
    func testABusThatChangesCountsItsWholeTrip() {
        var changing = plan
        changing.change = BusChange(firstBus: "3", thenBus: "4", ride1: 8, change: 5, ride2: 6)
        XCTAssertEqual(changing.routes.map(\.trip), [10, 19])
        // Bus 3 in 12 reaches in 31; bus 1 in 25 reaches in 35.
        let live = LiveMorning(arrivals: [bus("1", 25), bus("3", 12)], plan: changing, minute: 400, start: start)
        XCTAssertEqual(live.chosen?.arrival, bus("3", 12))
        XCTAssertEqual(live.chosen?.route.then, "4")
        changing.services = ["1", "3"]
        XCTAssertEqual(LiveMorning(arrivals: [bus("3", 12)], plan: changing, minute: 400, start: start)
            .chosen?.route, BusRoute(service: "3", then: nil, trip: 10))
    }

    func testPillsToggleInPillOrder() {
        let order = ["12", "34", "56"]
        var list = BusPlan.toggling("56", in: [], order: order)
        list = BusPlan.toggling("12", in: list, order: order)
        XCTAssertEqual(list, ["12", "56"])
        XCTAssertEqual(BusPlan.toggling("34", in: list, order: order), ["12", "34", "56"])
        XCTAssertEqual(BusPlan.toggling("12", in: list, order: order), ["56"])
        XCTAssertEqual(BusPlan.toggling("99", in: list, order: order), ["12", "56", "99"])
    }

    func testBusNumbersAreDigitsAndALetter() {
        XCTAssertTrue(BusChange.isServiceNumber("12"))
        XCTAssertTrue(BusChange.isServiceNumber("34A"))
        XCTAssertFalse(BusChange.isServiceNumber("A3"))
        XCTAssertFalse(BusChange.isServiceNumber("12AB"))
        XCTAssertFalse(BusChange.isServiceNumber(""))
    }

    // MARK: Plans saved by older builds

    private func decode(_ json: String) throws -> BusPlan {
        try JSONDecoder().decode(BusPlan.self, from: Data(json.utf8))
    }

    private let kid = "5EED0000-0000-4000-8000-0000000000A1"

    func testAOneBusPlanFromBeforeEventsDecodes() throws {
        let decoded = try decode(#"{"kid":"\#(kid)","stop":"00000","services":["1"],"walk":8,"ride":12,"lateGrace":15}"#)
        XCTAssertEqual(decoded.event, .school)
        XCTAssertEqual(decoded.routes, [BusRoute(service: "1", then: nil, trip: 12)])
    }

    func testAFirstAndSecondBecomeTwoEqualBusesWithTheirRides() throws {
        let decoded = try decode(#"{"kid":"\#(kid)","stop":"00000","services":["1","2"],"walk":8,"ride":12,"#
            + #""lateGrace":15,"secondRide":20}"#)
        XCTAssertEqual(decoded.services, ["1", "2"])
        XCTAssertEqual(decoded.ride(on: "1"), 12)
        XCTAssertEqual(decoded.ride(on: "2"), 20)
    }

    func testAChangingSecondBecomesTheBusThatChanges() throws {
        let decoded = try decode(#"{"kid":"\#(kid)","stop":"00000","services":["1"],"walk":8,"ride":12,"#
            + #""lateGrace":15,"change":{"firstBus":"3","stop":"00001","thenBus":"4","ride1":8,"walk":3,"ride2":6}}"#)
        XCTAssertEqual(decoded.change, BusChange(firstBus: "3", thenBus: "4", ride1: 8, change: 3, ride2: 6))
        XCTAssertEqual(decoded.routes.map(\.trip), [12, 17])
    }

    func testOlderPlansWithMoreBusesKeepThemAll() throws {
        let decoded = try decode(#"{"kid":"\#(kid)","stop":"00000","services":["1","2","3"],"walk":8,"ride":12,"#
            + #""lateGrace":15}"#)
        XCTAssertEqual(decoded.services, ["1", "2", "3"])
    }

    func testANewPlanRoundTrips() throws {
        var full = plan
        full.services = ["1", "2"]
        full.rides = ["2": 20]
        full.change = BusChange(firstBus: "3", thenBus: "4")
        XCTAssertEqual(try JSONDecoder().decode(BusPlan.self, from: JSONEncoder().encode(full)), full)
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
        let targets = try XCTUnwrap(LiveMorning.leaveTargets(arrivals: [bus("1", 14), bus("1", 21), bus("1", 29)],
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
