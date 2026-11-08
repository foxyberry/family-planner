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
                       [HubRow(key: "Age", value: "8 · Year 3"), HubRow(key: "Day", value: "Up 6:30 am · Bed 8:00 pm")])
    }

    func testAboutRowsForHomeKid() {
        XCTAssertEqual(HubModel.aboutRows(kid: SeedData.kidB, routines: SeedData.routines),
                       [HubRow(key: "Age", value: "4 · at home"), HubRow(key: "Day", value: "Nap 1:00–3:00 pm · Bed 7:30 pm")])
    }

    func testSchoolRows() {
        XCTAssertEqual(HubModel.schoolRows(kid: SeedData.kidA),
                       [HubRow(key: "School", value: "Example Primary School"),
                        HubRow(key: "Hours", value: "7:30 am–3:00 pm"),
                        HubRow(key: "Holidays", value: "No holidays set")])
        XCTAssertEqual(HubModel.schoolRows(kid: SeedData.kidB), [])
    }

    func testSectionsForSchoolKid() {
        let sections = HubModel.sections(kid: SeedData.kidA, routines: SeedData.routines)
        XCTAssertEqual(sections.map(\.title), ["About", "School"])
        XCTAssertEqual(sections[0].rows, [.text(HubRow(key: "Age", value: "8 · Year 3")),
                                          .text(HubRow(key: "Day", value: "Up 6:30 am · Bed 8:00 pm"))])
        XCTAssertEqual(sections[1].rows, [
            .text(HubRow(key: "School", value: "Example Primary School")),
            .schoolDays(key: "Days", days: Weekday.schoolDays),
            .text(HubRow(key: "Hours", value: "7:30 am–3:00 pm")),
            .text(HubRow(key: "Holidays", value: "No holidays set")),
        ])
    }

    func testSectionsForHomeKid() {
        let sections = HubModel.sections(kid: SeedData.kidB, routines: SeedData.routines)
        XCTAssertEqual(sections.map(\.title), ["About", "Nursery", "Morning"])
        XCTAssertEqual(sections[1].rows, [.text(HubRow(key: "Nursery", value: "Not yet"))])
        XCTAssertEqual(sections[2].rows, [.text(HubRow(key: "Taps", value: "A grown-up taps for now"))])
    }

    func testWeeklyHeading() {
        XCTAssertEqual(HubModel.weeklyHeading(kid: SeedData.kidA), "After school")
        XCTAssertEqual(HubModel.weeklyHeading(kid: SeedData.kidB), "Every week")
    }

    func testWeeklyRowsText() {
        let rows = HubModel.weeklyRows(kid: SeedData.kidA, items: [
            F.weekly(), F.weekly("Reading", days: Weekday.schoolDays, start: 960, end: 1000),
        ])
        XCTAssertEqual(rows.map(\.detail), ["Mon · Wed 3:30–4:30 pm", "Every school day 4:00–4:40 pm"])
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
        // 6:00 am on Monday: Kid A wakes at 6:30, so last night's event is still listed.
        let early = HubModel.onceRows(kid: SeedData.kidA, items: items, routines: SeedData.routines, today: F.monday,
                                      nowMinute: 360, calendar: F.calendar)
        XCTAssertEqual(early.map(\.title), ["Last night", "Event 6", "Event 5", "Event 4", "Event 3"])
        XCTAssertEqual(early.first?.detail, "Sun 8 Nov · 4:00–5:00 pm")
        let later = HubModel.onceRows(kid: SeedData.kidA, items: items, routines: SeedData.routines, today: F.monday,
                                      nowMinute: 390, calendar: F.calendar)
        XCTAssertEqual(later.first?.title, "Event 6", "gone at wake-up")
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

    func testRowsFollowTheSelectedKid() async {
        let party = F.once("Party", on: Day(year: 2026, month: 11, day: 11), audience: .kid(SeedData.kidA.id))
        let store = store(items: [F.weekly(), party])
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.calendar, F.calendar)
        XCTAssertEqual(store.state.weeklyRows.map(\.title), ["Swimming"])
        XCTAssertEqual(store.state.onceRows.map(\.detail), ["Wed 11 Nov · 4:00–5:00 pm"])
        XCTAssertEqual(store.state.weeklyHeading, "After school")
        XCTAssertEqual(store.state.sections.map(\.title), ["About", "School"])
        await store.send(.kidTabTapped(SeedData.kidB.id))
        XCTAssertEqual(store.state.weeklyRows, [])
        XCTAssertEqual(store.state.onceRows, [])
        XCTAssertEqual(store.state.weeklyHeading, "Every week")
        XCTAssertEqual(store.state.sections.map(\.title), ["About", "Nursery", "Morning"])
    }

    func testNoJustOnceRowsBeforeTodayIsKnown() {
        var state = GrownupHubFeature.State()
        state.snapshot = F.snapshot(items: [F.weekly(), F.once("Party", on: F.monday)])
        state.selectedKid = SeedData.kidA.id
        XCTAssertNil(state.today)
        XCTAssertEqual(state.onceRows, [])
        XCTAssertEqual(state.weeklyRows.map(\.title), ["Swimming"], "every-week rows need no date")
    }

    func testNothingToShowBeforeLoading() {
        let state = GrownupHubFeature.State()
        XCTAssertEqual(state.sections, [])
        XCTAssertEqual(state.weeklyRows, [])
        XCTAssertEqual(state.onceRows, [])
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
