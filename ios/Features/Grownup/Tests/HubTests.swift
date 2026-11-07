import ComposableArchitecture
import Domain
import Foundation
import Grownup
import ScheduleStore
import XCTest

final class HubModelTests: XCTestCase {
    private typealias F = Fixture

    func testAboutRowsForSchoolKid() {
        XCTAssertEqual(HubModel.aboutRows(kid: SeedData.kidA, routines: SeedData.routines),
                       [HubRow(key: "Age", value: "8 · Year 3"), HubRow(key: "Day", value: "Up 7:00 · Bed 8:30")])
    }

    func testAboutRowsForHomeKid() {
        XCTAssertEqual(HubModel.aboutRows(kid: SeedData.kidB, routines: SeedData.routines),
                       [HubRow(key: "Age", value: "4 · at home"), HubRow(key: "Day", value: "Nap 1:00–2:30 · Bed 7:30")])
    }

    func testSchoolRows() {
        XCTAssertEqual(HubModel.schoolRows(kid: SeedData.kidA),
                       [HubRow(key: "School", value: "Example Primary School"),
                        HubRow(key: "Hours", value: "8:00 am – 3:00 pm"),
                        HubRow(key: "Holidays", value: "No holidays set")])
        XCTAssertEqual(HubModel.schoolRows(kid: SeedData.kidB), [])
    }

    func testWeeklyRowsText() {
        let rows = HubModel.weeklyRows(kid: SeedData.kidA, items: [
            F.weekly(), F.weekly("Reading", days: Weekday.schoolDays, start: 960, end: 1000),
        ])
        XCTAssertEqual(rows.map(\.detail), ["Mon · Wed 3:30–4:30", "Every school day 4:00–4:40"])
    }

    func testEndedSeriesNotListed() {
        let rows = HubModel.weeklyRows(kid: SeedData.kidA, items: [F.weekly(until: F.monday)])
        XCTAssertEqual(rows, [])
    }

    func testOtherKidsItemsNotListed() {
        XCTAssertEqual(HubModel.weeklyRows(kid: SeedData.kidB, items: [F.weekly()]), [])
    }

    func testOnceRowsNearestFirstMaxFiveUntilNextWakeUp() {
        let yesterday = Day(year: 2026, month: 11, day: 8)
        let items = (0..<7).map { F.once("Event \($0)", on: F.monday.adding(days: 6 - $0, calendar: F.calendar)) }
            + [F.once("Last night", on: yesterday), F.once("Last week", on: Day(year: 2026, month: 11, day: 1))]
        // 6:30 am on Monday: Kid A wakes at 7:00, so last night's event is still listed.
        let early = HubModel.onceRows(kid: SeedData.kidA, items: items, routines: SeedData.routines, today: F.monday,
                                      nowMinute: 390, calendar: F.calendar)
        XCTAssertEqual(early.map(\.title), ["Last night", "Event 6", "Event 5", "Event 4", "Event 3"])
        XCTAssertEqual(early.first?.detail, "Sun 8 Nov · 4:00–5:00")
        let later = HubModel.onceRows(kid: SeedData.kidA, items: items, routines: SeedData.routines, today: F.monday,
                                      nowMinute: 480, calendar: F.calendar)
        XCTAssertEqual(later.first?.title, "Event 6")
    }
}

@MainActor
final class GrownupHubFeatureTests: XCTestCase {
    private typealias F = Fixture

    private func store(items: [ScheduleItem] = [F.weekly()]) -> TestStoreOf<GrownupHubFeature> {
        let snapshot = F.snapshot(items: items)
        let store = TestStore(initialState: GrownupHubFeature.State()) {
            GrownupHubFeature()
        } withDependencies: {
            $0.calendar = F.calendar
            $0.date.now = F.monday.date(minute: 600, calendar: F.calendar)
            $0.scheduleStore.load = { snapshot }
        }
        store.exhaustivity = .off
        return store
    }

    func testLoadSelectsFirstKid() async {
        let store = store()
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.selectedKid, SeedData.kidA.id)
        XCTAssertEqual(store.state.today, F.monday)
        XCTAssertEqual(store.state.nowMinute, 600)
    }

    func testTabSwitchKeepsData() async {
        let store = store()
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.kidTabTapped(SeedData.kidB.id))
        XCTAssertEqual(store.state.selectedKid, SeedData.kidB.id)
        XCTAssertEqual(store.state.snapshot?.items.count, 1)
    }

    func testReloadKeepsSelectedKid() async {
        let store = store()
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.kidTabTapped(SeedData.kidB.id))
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.selectedKid, SeedData.kidB.id)
    }
}
