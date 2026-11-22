import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import HolidayProvider
import ScheduleStore
import SchoolDirectory
import SchoolYear
import XCTest

/// Spec K1 · School calendar (boards K1, K1o, K1n; layout v74). Today is Tuesday 10 Nov 2026 in
/// Singapore, no holiday. Holidays and breaks come from the bundled 2026–2027 lists: Hari Raya Puasa
/// 21 Mar inside the March holidays (14–22 Mar), Labour Day 1 May, Deepavali 8 Nov and its observed
/// day 9 Nov, the year-end break from 21 Nov, Christmas 25 Dec inside it.
@MainActor
final class SchoolYearFeatureTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return calendar
    }()
    private let today = Day(year: 2026, month: 11, day: 10)

    nonisolated private static let holidays2026 = [
        Holiday(day: Day(year: 2026, month: 3, day: 21), name: "Hari Raya Puasa"),
        Holiday(day: Day(year: 2026, month: 5, day: 1), name: "Labour Day"),
        Holiday(day: Day(year: 2026, month: 11, day: 8), name: "Deepavali"),
        Holiday(day: Day(year: 2026, month: 11, day: 9), name: "Deepavali (observed)"),
        Holiday(day: Day(year: 2026, month: 12, day: 25), name: "Christmas Day"),
    ]
    nonisolated private static let holidays2027 = [Holiday(day: Day(year: 2027, month: 1, day: 1), name: "New Year's Day")]

    /// The MOE primary breaks (named days), from the bundled 2026 list.
    private func breaks() -> [Day: String] {
        var names: [Day: String] = [:]
        for day in 14...22 { names[Day(year: 2026, month: 3, day: day)] = "March holidays" }
        for day in 21...30 { names[Day(year: 2026, month: 11, day: day)] = "End-of-year holidays" }
        for day in 1...31 { names[Day(year: 2026, month: 12, day: day)] = "End-of-year holidays" }
        return names
    }

    private func kids(bothAtSchool: Bool) -> [Kid] {
        var kidB = SeedData.kidB
        if bothAtSchool { kidB.school = SeedData.kidA.school }
        return [SeedData.kidA, kidB]
    }

    private func store(kids: [Kid]? = nil, holidays2027: [Holiday] = holidays2027) -> TestStoreOf<SchoolYearFeature> {
        let kids = kids ?? self.kids(bothAtSchool: false)
        let breaks = breaks()
        let store = TestStore(initialState: SchoolYearFeature.State(look: .day)) {
            SchoolYearFeature()
        } withDependencies: { [calendar, today, holidays2026 = Self.holidays2026] in
            $0.calendar = calendar
            $0.date.now = today.date(minute: 600, calendar: calendar)
            $0.scheduleStore.load = { ScheduleSnapshot(kids: kids, routines: [], items: [], missions: []) }
            $0.holidays.holidays = { year in year == 2026 ? holidays2026 : year == 2027 ? holidays2027 : [] }
            $0.schoolDirectory.calendar = { _, _ in SchoolCalendar(closed: Set(breaks.keys), breaks: breaks) }
        }
        store.exhaustivity = .off
        return store
    }

    /// The mark a month card shows for `day` in the picked year.
    private func mark(_ screen: SchoolYearFeature.State.Screen, _ day: Day) -> CalendarCell.Mark? {
        screen.months[day.month - 1].weeks.joined().compactMap { $0 }.first { $0.number == "\(day.day)" }
    }

    func testNothingIsDrawnUntilTheYearLoads() async {
        let store = store()
        XCTAssertNil(store.state.screen)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertNotNil(store.state.screen)
    }

    /// Spec K1 "Marks": Kid A's breaks in Kid A's colour, public holidays red on light red, inside a
    /// break the kid colour stays with a red numeral, today's disc; Kid B (at home) has no days off.
    func testTheYearShowsEachKidsDaysOffHolidaysAndToday() async throws {
        let store = store()
        await store.send(.task)
        await store.receive(\.loaded)
        let screen = try XCTUnwrap(store.state.screen)
        XCTAssertEqual(screen.pickedYear, 2026)
        XCTAssertEqual(screen.tabs.map(\.0), [2026, 2027], "only the years the data has")
        XCTAssertEqual(screen.tabs.map(\.1), ["2026", "2027"])
        XCTAssertEqual(screen.months.map(\.title).prefix(3), ["January", "February", "March"])
        XCTAssertEqual(screen.months.count, 12)
        XCTAssertEqual(screen.weekdays, ["M", "T", "W", "T", "F", "S", "S"], "one letter at 24 (layout v74)")
        let a = SeedData.kidA.colorIndex
        XCTAssertEqual(mark(screen, today), CalendarCell.Mark(number: "10", isToday: true))
        XCTAssertEqual(mark(screen, Day(year: 2026, month: 11, day: 9)), CalendarCell.Mark(number: "9", isHoliday: true))
        XCTAssertEqual(mark(screen, Day(year: 2026, month: 5, day: 1)), CalendarCell.Mark(number: "1", isHoliday: true))
        XCTAssertEqual(mark(screen, Day(year: 2026, month: 3, day: 21)), CalendarCell.Mark(number: "21", kids: [a], isHoliday: true))
        XCTAssertEqual(mark(screen, Day(year: 2026, month: 12, day: 25)), CalendarCell.Mark(number: "25", kids: [a], isHoliday: true))
        // A break's first and last days are in it; the days around it are not.
        XCTAssertEqual(mark(screen, Day(year: 2026, month: 3, day: 14)), CalendarCell.Mark(number: "14", kids: [a]))
        XCTAssertEqual(mark(screen, Day(year: 2026, month: 3, day: 22)), CalendarCell.Mark(number: "22", kids: [a]))
        XCTAssertEqual(mark(screen, Day(year: 2026, month: 3, day: 13)), CalendarCell.Mark(number: "13"))
        XCTAssertEqual(mark(screen, Day(year: 2026, month: 3, day: 23)), CalendarCell.Mark(number: "23"))
        XCTAssertEqual(mark(screen, Day(year: 2026, month: 11, day: 20)), CalendarCell.Mark(number: "20"))
        XCTAssertEqual(mark(screen, Day(year: 2026, month: 11, day: 21)), CalendarCell.Mark(number: "21", kids: [a]))
        // November 2026 starts on a Sunday: six blanks first.
        XCTAssertEqual(screen.months[10].weeks[0].prefix(6).compactMap { $0 }, [])
    }

    /// The legend: a kid at home has no days off, so only the kids at school are listed; "Both off"
    /// only with two of them. Today's swatch carries today's numeral.
    func testTheLegendListsTheKidsAtSchool() async throws {
        let one = store()
        await one.send(.task)
        await one.receive(\.loaded)
        let legend = try XCTUnwrap(one.state.screen).legend
        XCTAssertEqual(legend.map(\.label), ["Kid A off", "Public holiday", "Today"])
        XCTAssertEqual(legend[0].face, KidFace.Badge(face: SeedData.kidA.face, colorIndex: SeedData.kidA.colorIndex))
        XCTAssertEqual(legend[0].swatch.kids, [SeedData.kidA.colorIndex])
        XCTAssertEqual(legend[1].swatch, CalendarCell.Mark(number: "25", isHoliday: true))
        XCTAssertEqual(legend[2].swatch, CalendarCell.Mark(number: "10", isToday: true))

        let two = store(kids: kids(bothAtSchool: true))
        await two.send(.task)
        await two.receive(\.loaded)
        let screen = try XCTUnwrap(two.state.screen)
        XCTAssertEqual(screen.legend.map(\.label), ["Kid A off", "Kid B off", "Both off", "Public holiday", "Today"])
        XCTAssertEqual(screen.legend[2].swatch.kids, [SeedData.kidA.colorIndex, SeedData.kidB.colorIndex])
        XCTAssertEqual(mark(screen, Day(year: 2026, month: 11, day: 23))?.kids,
                       [SeedData.kidA.colorIndex, SeedData.kidB.colorIndex], "both off: the cell splits")

        // Spec #261: a kid at a preschool counts too.
        var preschooler = SeedData.kidB
        preschooler.school = School(name: "Example Preschool", days: Weekday.schoolDays, start: 480, end: 720, // copy-ok: test data
                                    kind: .preschool)
        let withPreschool = store(kids: [SeedData.kidA, preschooler])
        await withPreschool.send(.task)
        await withPreschool.receive(\.loaded)
        XCTAssertEqual(try XCTUnwrap(withPreschool.state.screen).legend.map(\.label),
                       ["Kid A off", "Kid B off", "Both off", "Public holiday", "Today"])

        // Spec v74: "Both off" only when the family has exactly two kids (a third kid at home here).
        var kidC = SeedData.kidB
        kidC.id = UUID(uuidString: "00000000-0000-0000-0000-0000000000C1")!
        kidC.name = "Kid C"
        kidC.school = nil
        kidC.colorIndex = 2
        let three = store(kids: kids(bothAtSchool: true) + [kidC])
        await three.send(.task)
        await three.receive(\.loaded)
        XCTAssertEqual(try XCTUnwrap(three.state.screen).legend.map(\.label), ["Kid A off", "Kid B off", "Public holiday", "Today"])
    }

    func testAYearWithoutDataHasNoTab() async throws {
        let store = store(holidays2027: [])
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(try XCTUnwrap(store.state.screen).tabs.map(\.0), [2026])
    }

    /// Board K1o: a tapped card opens over the year; "×" or a tap outside closes it; a year tab
    /// shows that year (and closes an open month).
    func testAMonthOpensInPlaceAndTheYearTabsSwitch() async throws {
        let store = store()
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.monthTapped(11)) { $0.openMonth = 11 }
        var screen = try XCTUnwrap(store.state.screen)
        let open = try XCTUnwrap(screen.open)
        XCTAssertEqual(open.title, "November 2026")
        XCTAssertEqual(screen.openWeekdays, ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
        XCTAssertEqual(open.weeks, screen.months[10].weeks, "the same marks as on the card")
        await store.send(.closeTapped) { $0.openMonth = nil }
        await store.send(.monthTapped(3)) { $0.openMonth = 3 }
        await store.send(.dimTapped) { $0.openMonth = nil }
        await store.send(.monthTapped(1)) { $0.openMonth = 1 }
        await store.send(.yearTapped(2027)) { $0.openMonth = nil }
        screen = try XCTUnwrap(store.state.screen)
        XCTAssertEqual(screen.pickedYear, 2027)
        XCTAssertEqual(mark(screen, Day(year: 2027, month: 1, day: 1)), CalendarCell.Mark(number: "1", isHoliday: true))
        XCTAssertEqual(mark(screen, Day(year: 2027, month: 11, day: 10))?.isToday, false, "today is in 2026")
        await store.send(.yearTapped(2030))
        XCTAssertEqual(store.state.screen?.pickedYear, 2027, "a year without a tab is ignored")
    }

    /// Review of #259: open past midnight, the calendar moves today's pill to the new day (the root's
    /// tick, as home does). A tick on the same day loads nothing; a picked year stays picked.
    func testTodayMovesWhenTheDayChanges() async throws {
        let store = store()
        await store.send(.task)
        await store.receive(\.loaded)
        store.exhaustivity = .on
        await store.send(.tick(today.date(minute: 1439, calendar: calendar)))
        store.exhaustivity = .off
        await store.send(.yearTapped(2027)) { $0.openMonth = nil }
        let wednesday = Day(year: 2026, month: 11, day: 11)
        await store.send(.tick(wednesday.date(minute: 0, calendar: calendar)))
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.screen?.pickedYear, 2027, "the pick stays")
        await store.send(.yearTapped(2026))
        let screen = try XCTUnwrap(store.state.screen)
        XCTAssertEqual(mark(screen, wednesday)?.isToday, true)
        XCTAssertEqual(mark(screen, today)?.isToday, false)
        XCTAssertEqual(screen.legend.last?.swatch.number, "11")
    }

    func testBackFinishes() async {
        let store = store()
        await store.send(.backTapped)
        await store.receive(.delegate(.finished))
    }
}
