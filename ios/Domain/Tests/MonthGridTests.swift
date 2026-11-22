import Domain
import XCTest

/// Spec K1 "Layout": six weeks of seven, Monday first, blanks outside the month.
final class MonthGridTests: XCTestCase {
    private func calendar(firstWeekday: Int = 1) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    func testNovember2026StartsOnSunday() {
        let grid = MonthGrid(year: 2026, month: 11, calendar: calendar())
        XCTAssertEqual(grid.weeks.count, 6)
        XCTAssertTrue(grid.weeks.allSatisfy { $0.count == 7 })
        // 1 Nov 2026 is a Sunday: six blanks, then the 1st in the last column.
        XCTAssertEqual(Array(grid.weeks[0].prefix(6)), [nil, nil, nil, nil, nil, nil])
        XCTAssertEqual(grid.weeks[0][6], Day(year: 2026, month: 11, day: 1))
        XCTAssertEqual(grid.weeks[1][0], Day(year: 2026, month: 11, day: 2), "Monday the 2nd starts the next row")
        // The 30th is a Monday in the sixth row; the rest of that row is blank.
        XCTAssertEqual(grid.weeks[5][0], Day(year: 2026, month: 11, day: 30))
        XCTAssertEqual(Array(grid.weeks[5].dropFirst()), [nil, nil, nil, nil, nil, nil])
        XCTAssertEqual(grid.weeks.joined().compactMap { $0 }.count, 30)
    }

    func testMondayFirstWhateverTheCalendarSays() {
        // A calendar whose week starts on Sunday (US) or Saturday draws the same grid.
        let monday = MonthGrid(year: 2026, month: 12, calendar: calendar(firstWeekday: 2))
        XCTAssertEqual(MonthGrid(year: 2026, month: 12, calendar: calendar(firstWeekday: 1)), monday)
        XCTAssertEqual(MonthGrid(year: 2026, month: 12, calendar: calendar(firstWeekday: 7)), monday)
        // 1 Dec 2026 is a Tuesday: one blank.
        XCTAssertNil(monday.weeks[0][0])
        XCTAssertEqual(monday.weeks[0][1], Day(year: 2026, month: 12, day: 1))
    }

    func testAMonthStartingOnMondayHasNoLeadingBlank() {
        // 1 Jun 2026 is a Monday; February 2027 has 28 days.
        XCTAssertEqual(MonthGrid(year: 2026, month: 6, calendar: calendar()).weeks[0][0], Day(year: 2026, month: 6, day: 1))
        let february = MonthGrid(year: 2027, month: 2, calendar: calendar())
        XCTAssertEqual(february.weeks.joined().compactMap { $0 }.last, Day(year: 2027, month: 2, day: 28))
    }

    func testTheLongestMonthFitsSixRows() {
        // August 2026 starts on a Saturday: 5 blanks + 31 days run into the sixth row.
        let august = MonthGrid(year: 2026, month: 8, calendar: calendar())
        XCTAssertEqual(august.weeks[5][0], Day(year: 2026, month: 8, day: 31))
        XCTAssertEqual(MonthGrid.year(2026, calendar: calendar()).map(\.month), Array(1...12))
    }

    func testWeekdayLettersRunMondayFirst() {
        XCTAssertEqual(DayText.mondayFirst.map(DayText.initial), ["M", "T", "W", "T", "F", "S", "S"])
    }
}
