import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import HolidayProvider
import Missions
import ScheduleStore
import XCTest

@MainActor
final class MissionsTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return calendar
    }()
    private let tuesday = Day(year: 2026, month: 11, day: 10)
    private let saturday = Day(year: 2026, month: 11, day: 14)
    private let kidA = SeedData.kidA.id
    private let kidB = SeedData.kidB.id

    private func store(on day: Day, minute: Int, missions: [Mission] = SeedData.missions,
                       saved: LockIsolated<[MissionDay]> = LockIsolated([]),
                       arrivals: [BusArrival]? = nil) -> TestStoreOf<MissionsFeature> {
        // Made-up stop and bus numbers (privacy rule).
        let plans = arrivals == nil ? [] : [BusPlan(kid: SeedData.kidA.id, stop: "00000", services: ["1"])]
        let snapshot = ScheduleSnapshot(kids: SeedData.kids, routines: SeedData.routines,
                                        items: SeedData.items(today: tuesday, calendar: calendar), missions: missions,
                                        busPlans: plans)
        let store = TestStore(initialState: MissionsFeature.State()) {
            MissionsFeature()
        } withDependencies: { [calendar] in
            $0.calendar = calendar
            $0.date.now = day.date(minute: minute, calendar: calendar)
            $0.continuousClock = TestClock()
            $0.scheduleStore.load = { snapshot }
            $0.scheduleStore.missionDay = { kid, date in
                saved.value.first { $0.kid == kid && $0.date == date } ?? MissionDay(kid: kid, date: date)
            }
            $0.scheduleStore.saveMissionDay = { day in
                saved.withValue { list in
                    list.removeAll { $0.kid == day.kid && $0.date == day.date }
                    list.append(day)
                }
            }
            $0.holidays.holidays = { _ in [] }
            // nil: no live times (no key built in), so the call fails and the timetable shows.
            $0.bus.arrivals = { _ in
                guard let arrivals else { throw URLError(.userAuthenticationRequired) }
                return arrivals
            }
        }
        store.exhaustivity = .off
        return store
    }

    private func id(_ suffix: String) -> Mission.ID { UUID(uuidString: "5EED0000-0000-4000-8000-000000000\(suffix)")! }

    /// Board A2-MVP, Tuesday 6:52 am: Kid A leaves first (bus at 7:25 am), the road goes to school.
    func testTuesdayMorningShowsTheWayToSchool() async {
        let store = store(on: tuesday, minute: 412)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.chosen, kidA)
        XCTAssertEqual(store.state.leaveAt, "leave at 7:25 am")
        let way = try? XCTUnwrap(store.state.way)
        XCTAssertEqual(way?.cardCaption, "by bus · no live times")
        XCTAssertEqual(way?.homeLabel, "Our stop")
        XCTAssertEqual(way?.place, "School")
        XCTAssertEqual(way?.showsStops, true)
        XCTAssertEqual(store.state.header?.minutes, "33 min")
        XCTAssertEqual(way?.moverX, 60) // 33 min to leave: 30 or more sits at x 60
        XCTAssertEqual(store.state.rows.map(\.total), [6, 3])
        XCTAssertEqual(store.state.state(caption: 0), "0 of 6 done")
    }

    /// Board A2-MVP-w, Saturday 8:00 am: weekend school by car, "Home" on the stem, no stops.
    func testSaturdayGoesByCarFromHome() async {
        let store = store(on: saturday, minute: 480)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.chosen, kidA)
        XCTAssertEqual(store.state.way?.homeLabel, "Home")
        XCTAssertEqual(store.state.way?.showsStops, false)
        XCTAssertEqual(store.state.way?.cardCaption, "by car")
        XCTAssertEqual(store.state.leaveAt, "leave at 8:35 am")
    }

    func testTappingAMissionTicksAndUnticksItAndSaves() async {
        let saved = LockIsolated<[MissionDay]>([])
        let store = store(on: tuesday, minute: 412, saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)

        await store.send(.missionTapped(id("301")))
        XCTAssertEqual(store.state.rows.first?.done, 1)
        XCTAssertEqual(store.state.state(caption: 0), "1 of 6 done")
        // The first open mission is the bold one.
        XCTAssertEqual(store.state.circles.first { if case .mission(_, _, true) = $0 { true } else { false } }?.id,
                       id("302").uuidString)
        await store.finish(timeout: .seconds(1))
        XCTAssertEqual(saved.value.first?.done, [id("301")])

        await store.send(.missionTapped(id("301")))
        XCTAssertEqual(store.state.rows.first?.done, 0)
    }

    /// Every kid slides (user, 2026-11-09): Kid B has no outing, so "All done? Slide!" with the star,
    /// no medal, and the check with "Ready!" in the done view.
    func testAKidWithNoOutingSlidesWithTheStar() async {
        let store = store(on: tuesday, minute: 412)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.kidTapped(kidB))
        XCTAssertTrue(store.state.slides)
        XCTAssertEqual(store.state.slideTitle, "All done? Slide!")
        XCTAssertEqual(store.state.slideKnob, .star)
        await store.send(.slid)
        XCTAssertEqual(store.state.days[kidB]?.medal, MorningMedal.none)
        XCTAssertNil(store.state.done?.medal)
        XCTAssertEqual(store.state.done?.title, "Ready!")
        await store.send(.backTapped)
        await store.receive(\.delegate.finished)
    }

    func testTappingAMissionPlaysItsPicture() async {
        let store = store(on: tuesday, minute: 412)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.missionTapped(id("303")))
        XCTAssertEqual(store.state.plays[id("303")], 1)
        await store.send(.backTapped)
    }

    func testTappingAKidChoosesThem() async {
        let store = store(on: tuesday, minute: 412)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.kidTapped(kidB)) { $0.chosen = self.kidB }
        XCTAssertEqual(store.state.circles.count, 3)
    }

    /// Spec "Whose outing": the strip shows the family's next outing whichever kid is chosen; Kid B
    /// has no trip of their own, so no "leave at".
    func testKidBKeepsTheFamilyWay() async {
        let store = store(on: tuesday, minute: 412)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.kidTapped(kidB))
        XCTAssertEqual(store.state.way?.owner.id, kidA)
        XCTAssertEqual(store.state.way?.cardCaption, "by bus · no live times")
        XCTAssertEqual(store.state.header?.minutes, "33 min")
        XCTAssertNil(store.state.leaveAt)
        XCTAssertEqual(store.state.way?.spoken,
                       "Kid A's way to School, by bus, 38 minutes, School starts at 7:30 am.")
    }

    /// Spec "A2 live look": fresh live times give "Leave in" with "On time", and the chosen bus sets
    /// "leave at".
    func testLiveTimesShowLeaveInAndOnTime() async {
        let store = store(on: tuesday, minute: 412, arrivals: [BusArrival(service: "1", minutes: 4, type: .single),
                                                               BusArrival(service: "1", minutes: 28, type: .double)])
        await store.send(.task)
        await store.receive(\.loaded)
        await store.receive(\.refresh)
        await store.receive(\.arrivalsLoaded)
        XCTAssertEqual(store.state.live?.leaveIn, 18)
        XCTAssertEqual(store.state.header?.label, "Leave in")
        XCTAssertEqual(store.state.header?.minutes, "18 min")
        XCTAssertEqual(store.state.header?.status?.text, "On time")
        XCTAssertEqual(store.state.leaveAt, "leave at 7:10 am")
        // The strip: bus 1 in 4 min is too soon (faded, its own bubble), bus 1 in 28 min is the kid's.
        let buses = store.state.liveStrip?.buses ?? []
        XCTAssertEqual(buses.map(\.isMine), [false, true])
        XCTAssertEqual(buses.map(\.isTooSoon), [true, false])
        XCTAssertEqual(buses.map(\.showsBubble), [true, true])
        XCTAssertEqual(buses.last?.x, 860 - 28 * 800 / 30)
        XCTAssertEqual(store.state.liveSpoken,
                       "Live bus map. Bus 1 in 28 minutes, your bus. Leave in 18 minutes, On time.")
        await store.send(.backTapped)
    }

    /// Live times with no bus to catch (only one arriving now): "Ask a grown-up", no leave time, and
    /// the legend still shows the kid's bus number.
    func testNoCatchableBusKeepsTheLegendAndDropsLeaveAt() async {
        let store = store(on: tuesday, minute: 412, arrivals: [BusArrival(service: "1", minutes: 0, type: .double)])
        await store.send(.task)
        await store.receive(\.loaded)
        await store.receive(\.refresh)
        await store.receive(\.arrivalsLoaded)
        XCTAssertNil(store.state.live?.leaveIn)
        XCTAssertNil(store.state.leaveAt)
        XCTAssertNil(store.state.header?.label, "no \"Leave in\" before \"Ask a grown-up\"")
        XCTAssertEqual(store.state.header?.status?.text, "Ask a grown-up")
        XCTAssertEqual(store.state.liveStrip?.myService, "1")
        await store.send(.backTapped)
    }

    /// No live times: the bus fallback counts to "leave" with no status.
    func testBusFallbackCountsToLeave() async {
        let store = store(on: tuesday, minute: 412)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertNil(store.state.live)
        XCTAssertEqual(store.state.header?.label, "Leave in")
        XCTAssertEqual(store.state.header?.minutes, "33 min")
        XCTAssertNil(store.state.header?.status)
        await store.send(.backTapped)
    }

    /// Spec "Medal from the time only" and board A3r: leave 7:25, so 7:20 is gold; the kid stays
    /// chosen with the done view, then 3 s later the next kid comes up; dragging back undoes.
    func testSlideShowsTheDoneViewThenTheNextKidAndDragBackUndoes() async {
        let clock = TestClock()
        let store = store(on: tuesday, minute: 440)
        store.dependencies.continuousClock = clock
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertTrue(store.state.slides)
        await store.send(.slid)
        XCTAssertEqual(store.state.days[kidA]?.medal, .gold)
        XCTAssertEqual(store.state.days[kidA]?.readyAt, 440)
        XCTAssertEqual(store.state.caption(store.state.rows[0]), "Ready! Gold")
        XCTAssertEqual(store.state.rows[0].medal, .gold)
        XCTAssertEqual(store.state.chosen, kidA)
        XCTAssertEqual(store.state.done?.title, "Gold!")
        XCTAssertEqual(store.state.done?.subtitle, "Ready in good time!")
        await clock.advance(by: .seconds(3))
        await store.receive(\.readyShown)
        XCTAssertEqual(store.state.chosen, kidB)
        // Back to Kid A: the done view again; dragging the slide back undoes it.
        await store.send(.kidTapped(kidA))
        XCTAssertEqual(store.state.done?.medal, .gold)
        await store.send(.slideUndone)
        XCTAssertNil(store.state.days[kidA]?.medal)
        XCTAssertEqual(store.state.days[kidA]?.ready, false)
        XCTAssertNil(store.state.done)
        await store.send(.backTapped)
    }

    /// After the last outing has started the strip keeps its road with the mover arrived
    /// (user, 2026-11-09), for every kid; nothing counts down and no kid has a leave time.
    func testAStartedOutingKeepsItsRoad() async {
        let store = store(on: tuesday, minute: 11 * 60)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.way?.place, "School")
        XCTAssertEqual(store.state.way?.moverX, WayStrip.arrivedX)
        XCTAssertEqual(store.state.way?.cardCaption, "At School now")
        XCTAssertNil(store.state.leaveAt)
    }

    /// Eight missions with two kids: six places. Done ones fold into one tick; the last place
    /// is "+n" and turns the page.
    func testEightMissionsFoldAndPage() async {
        let extra = [Mission(id: id("307"), kid: kidA, name: "Water bottle", picture: "actPlay", order: 6),
                     Mission(id: id("308"), kid: kidA, name: "Hat", picture: "actPlay", order: 7)]
        let store = store(on: tuesday, minute: 412, missions: SeedData.missions + extra)
        await store.send(.task)
        await store.receive(\.loaded)

        // None done: five missions, then "+3".
        XCTAssertEqual(store.state.circles.count, 6)
        XCTAssertEqual(store.state.circles.last, .more(count: 3))
        await store.send(.moreTapped)
        XCTAssertEqual(store.state.circles.first?.id, id("306").uuidString)
        XCTAssertEqual(store.state.circles.last, .back)
        await store.send(.backPageTapped)
        XCTAssertEqual(store.state.circles.first?.id, id("301").uuidString)

        // Three done: one folded tick and the five open ones.
        for suffix in ["301", "302", "303"] { await store.send(.missionTapped(id(suffix))) }
        XCTAssertEqual(store.state.circles.first, .folded(count: 3))
        XCTAssertEqual(store.state.circles.count, 6)
        XCTAssertFalse(store.state.circles.contains { if case .more = $0 { true } else { false } })
    }
}

private extension MissionsFeature.State {
    func state(caption index: Int) -> String { caption(rows[index]) }
}
