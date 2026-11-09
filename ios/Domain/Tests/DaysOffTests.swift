import Domain
import XCTest

/// Spec "Repeats, dates and changes": each kid's days off, and an item's for its audience.
final class DaysOffTests: XCTestCase {
    private let kidA = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
    private let kidB = UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!
    private let monday = Day(year: 2026, month: 11, day: 23)
    private let tuesday = Day(year: 2026, month: 11, day: 24)

    func testAnItemForBothKidsIsOffOnlyWhenBothAre() {
        let daysOff = [kidA: Set([monday, tuesday]), kidB: Set([tuesday])]
        XCTAssertEqual(DayPlanner.daysOff(for: .kid(kidA), in: daysOff), [monday, tuesday])
        XCTAssertEqual(DayPlanner.daysOff(for: .both, in: daysOff), [tuesday])
        XCTAssertEqual(DayPlanner.daysOff(for: .kid(UUID()), in: daysOff), [])
    }

    func testASchoolCalendarAddsItsClosedDaysToThePublicHolidays() {
        let term = SchoolCalendar.Term(name: "Term 4", start: Day(year: 2026, month: 9, day: 14), end: Day(year: 2026, month: 11, day: 20))
        let year = SchoolCalendar(terms: [term], closed: [monday])
        XCTAssertEqual(year.daysOff(publicHolidays: [tuesday]), [monday, tuesday])
        XCTAssertEqual(year.termEnd(from: Day(year: 2026, month: 10, day: 1)), term.end)
        XCTAssertNil(year.termEnd(from: monday), "no term after the last one")
    }
}
