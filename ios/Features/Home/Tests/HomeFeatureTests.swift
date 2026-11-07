import ComposableArchitecture
import Domain
import Foundation
import HolidayProvider
import Home
import ScheduleStore
import XCTest

@MainActor
final class HomeFeatureTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return calendar
    }()
    private let tuesday = Day(year: 2026, month: 11, day: 10)
    private let wednesday = Day(year: 2026, month: 11, day: 11)
    private let saturday = Day(year: 2026, month: 11, day: 14)

    private func snapshot(kids: [Kid] = SeedData.kids) -> ScheduleSnapshot {
        ScheduleSnapshot(kids: kids, routines: SeedData.routines,
                         items: SeedData.items(today: tuesday, calendar: calendar))
    }

    private func store(on day: Day, minute: Int, snapshot: ScheduleSnapshot? = nil,
                       holidays: [Holiday] = []) -> TestStoreOf<HomeFeature> {
        let snapshot = snapshot ?? self.snapshot()
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: { [calendar] in
            $0.calendar = calendar
            $0.date.now = day.date(minute: minute, calendar: calendar)
            $0.scheduleStore.load = { snapshot }
            $0.holidays.holidays = { _ in holidays }
        }
        store.exhaustivity = .off
        return store
    }

    func testLoadsTwoKidsLayout() async {
        let store = store(on: wednesday, minute: 945)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.layout, .twoKids)
        XCTAssertEqual(store.state.today, wednesday)
        XCTAssertEqual(store.state.minute, 945)
        XCTAssertTrue(store.state.days.first?.slots.contains { $0.title == "Swimming" } ?? false)
    }

    func testOneKidLayout() async {
        let store = store(on: wednesday, minute: 600, snapshot: snapshot(kids: [SeedData.kidA]))
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.layout, .oneKid)
    }

    func testWeekendIsDayOffLayout() async {
        let store = store(on: saturday, minute: 600)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.layout, .dayOff)
    }

    func testHolidayIsDayOffLayout() async {
        let store = store(on: wednesday, minute: 600, holidays: [Holiday(day: wednesday, name: "Holiday")])
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.layout, .dayOff)
    }

    func testLoadFailureShowsAnEmptyDay() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: { [calendar, wednesday] in
            $0.calendar = calendar
            $0.date.now = wednesday.date(minute: 600, calendar: calendar)
            $0.scheduleStore.load = { throw CocoaError(.fileReadCorruptFile) }
            $0.holidays.holidays = { _ in [] }
        }
        store.exhaustivity = .off
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.days, [])
    }

    func testMidnightTickReloadsTheNewDay() async {
        let store = store(on: tuesday, minute: 1439)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertFalse(store.state.days.first?.slots.contains { $0.title == "Swimming" } ?? true)
        await store.send(.tick(wednesday.date(minute: 0, calendar: calendar)))
        XCTAssertEqual(store.state.today, wednesday)
        XCTAssertEqual(store.state.minute, 0)
        await store.receive(\.loaded)
        XCTAssertTrue(store.state.days.first?.slots.contains { $0.title == "Swimming" } ?? false)
    }

    func testTickBeforeTaskDoesNotLoad() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: { [calendar] in
            $0.calendar = calendar
        }
        await store.send(.tick(wednesday.date(minute: 601, calendar: calendar))) {
            $0.minute = 601
        }
    }

    func testMinuteTickMovesNowWithoutReload() async {
        let store = store(on: wednesday, minute: 600)
        store.exhaustivity = .on
        await store.send(.task) {
            $0.today = self.wednesday
            $0.minute = 600
        }
        await store.skipReceivedActions()
        await store.send(.tick(wednesday.date(minute: 601, calendar: calendar))) {
            $0.minute = 601
        }
    }
}
