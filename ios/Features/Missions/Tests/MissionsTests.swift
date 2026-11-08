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
                       saved: LockIsolated<[MissionDay]> = LockIsolated([])) -> TestStoreOf<MissionsFeature> {
        let snapshot = ScheduleSnapshot(kids: SeedData.kids, routines: SeedData.routines,
                                        items: SeedData.items(today: tuesday, calendar: calendar), missions: missions)
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
        XCTAssertEqual(way?.cardCaption, "by bus · timetable")
        XCTAssertEqual(way?.homeLabel, "Our stop")
        XCTAssertEqual(way?.place, "School")
        XCTAssertEqual(way?.showsStops, true)
        XCTAssertEqual(way?.headerMinutes, "38 min")
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

    /// Kids are never locked: "All done!" works with missions left, marks the kid ready and
    /// chooses the next kid; once everyone is ready it reads "Back to the clock" and leaves.
    func testAllDoneChoosesTheNextKidThenGoesBack() async {
        let store = store(on: tuesday, minute: 412)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.buttonTitle, "All done!")

        await store.send(.allDoneTapped)
        XCTAssertEqual(store.state.chosen, kidB)
        XCTAssertEqual(store.state.state(caption: 0), "Ready!")
        XCTAssertEqual(store.state.rows.first?.progress, 1)

        await store.send(.allDoneTapped)
        XCTAssertTrue(store.state.everyoneReady)
        XCTAssertEqual(store.state.buttonTitle, "Back to the clock")
        await store.send(.allDoneTapped)
        await store.receive(\.delegate.finished)
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
        XCTAssertEqual(store.state.way?.cardCaption, "by bus · timetable")
        XCTAssertEqual(store.state.way?.headerMinutes, "38 min")
        XCTAssertNil(store.state.leaveAt)
        XCTAssertEqual(store.state.way?.spoken,
                       "Kid A's way to School, by bus, 38 minutes, School starts at 7:30 am.")
    }

    /// After the last outing has started there is no way left: the strip shows its empty look.
    func testNoOutingLeftHasNoWay() async {
        let store = store(on: tuesday, minute: 11 * 60)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertNil(store.state.way)
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
