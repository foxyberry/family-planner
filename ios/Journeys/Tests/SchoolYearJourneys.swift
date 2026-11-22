import AppCore
import ComposableArchitecture
import DesignSystem
import Domain
import JourneyWorld
import SchoolYear
import XCTest

/// K1 · School calendar (spec K1, layout v74): from the kids' home, without the lock.
@MainActor
final class SchoolYearJourneys: XCTestCase {
    /// A kid taps the calendar on home, sees the year with Kid A's year-end break and Deepavali,
    /// opens November, taps outside to close it, looks at next year, and goes back home.
    func testAKidOpensTheSchoolCalendarFromHomeAndGoesBack() async throws {
        var data = WorldData.standard
        data.family = "sample"
        data.holidays = ["2026-11-08": "Deepavali", "2026-11-09": "Deepavali (observed)",
                         "2027-01-01": "New Year's Day"]
        data.breaks = [WorldData.Break(name: "End-of-year holidays", from: "2026-11-21", to: "2026-12-31")]
        let world = World(data)
        let store = world.store()
        await store.send(.home(.task))
        await store.receive(\.home.loaded)

        // The calendar button: no Face ID, the calendar over home.
        await store.send(.home(.calendarTapped))
        XCTAssertNil(store.state.lock)
        let calendar = try XCTUnwrap(store.state.path.ids.first)
        await store.send(.path(.element(id: calendar, action: .schoolYear(.task))))
        await store.receive(\.path[id: calendar].schoolYear.loaded)
        guard case let .schoolYear(year)? = store.state.path[id: calendar], let screen = year.screen else {
            return XCTFail("no school calendar")
        }
        XCTAssertEqual(screen.tabs.map(\.1), ["2026", "2027"])
        XCTAssertEqual(screen.legend.map(\.label), ["Kid A off", "Public holiday", "Today"])
        let november = screen.months[10].weeks.joined().compactMap { $0 }
        XCTAssertEqual(november[8], CalendarCell.Mark(number: "9", isHoliday: true), "Deepavali (observed)")
        XCTAssertEqual(november[9], CalendarCell.Mark(number: "10", isToday: true))
        XCTAssertEqual(november[20], CalendarCell.Mark(number: "21", kids: [SeedData.kidA.colorIndex]), "the break")

        // Tap November: it opens over the year; a tap outside closes it.
        await store.send(.path(.element(id: calendar, action: .schoolYear(.monthTapped(11)))))
        XCTAssertEqual(schoolYear(store, calendar)?.screen?.open?.title, "November 2026")
        await store.send(.path(.element(id: calendar, action: .schoolYear(.dimTapped))))
        XCTAssertNil(schoolYear(store, calendar)?.screen?.open)

        // Next year's tab.
        await store.send(.path(.element(id: calendar, action: .schoolYear(.yearTapped(2027)))))
        XCTAssertEqual(schoolYear(store, calendar)?.screen?.pickedYear, 2027)

        // "‹" goes back to the home it came from.
        await store.send(.path(.element(id: calendar, action: .schoolYear(.backTapped))))
        await store.receive(\.path[id: calendar].schoolYear.delegate.finished)
        XCTAssertTrue(store.state.path.isEmpty)
    }

    private func schoolYear(_ store: TestStoreOf<AppFeature>, _ id: StackElementID) -> SchoolYearFeature.State? {
        guard case let .schoolYear(year)? = store.state.path[id: id] else { return nil }
        return year
    }
}
