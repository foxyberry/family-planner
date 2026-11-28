import Domain
import XCTest

/// A school with its own term dates (spec S2 "Own terms"): the days between one term's end and the
/// next term's start are its holidays, whether or not its list names them.
final class SchoolCalendarTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return calendar
    }()

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Day { Day(year: year, month: month, day: day) }

    func testTheDaysBetweenTermsAreHolidays() {
        let term1 = SchoolCalendar.Term(name: "Term 1", start: day(2026, 8, 11), end: day(2026, 12, 11))
        let term2 = SchoolCalendar.Term(name: "Term 2", start: day(2027, 1, 5), end: day(2027, 3, 25))
        let halfTerm = Set([day(2026, 10, 12), day(2026, 10, 13)])
        let own = SchoolCalendar(terms: [term2, term1], closed: halfTerm,
                                 breaks: [day(2026, 10, 12): "Half-Term 1 Break", day(2026, 10, 13): "Half-Term 1 Break"])
            .withTermGaps(calendar: calendar)

        XCTAssertTrue(own.closed.contains(day(2026, 12, 12)), "the day after Term 1 ends")
        XCTAssertTrue(own.closed.contains(day(2026, 12, 25)))
        XCTAssertTrue(own.closed.contains(day(2027, 1, 4)), "the day before Term 2 starts")
        XCTAssertFalse(own.closed.contains(day(2026, 12, 11)), "Term 1's last day is a school day")
        XCTAssertFalse(own.closed.contains(day(2027, 1, 5)), "Term 2's first day is a school day")
        XCTAssertEqual(own.closed.filter { $0 >= day(2026, 12, 12) && $0 <= day(2027, 1, 4) }.count, 24)
        XCTAssertEqual(own.breaks[day(2026, 12, 20)], "School holidays")
        XCTAssertEqual(own.breaks[day(2026, 10, 12)], "Half-Term 1 Break", "a named break keeps its name")
        XCTAssertTrue(own.closed.isSuperset(of: halfTerm))
        XCTAssertFalse(own.closed.contains(day(2026, 8, 10)), "before the first term nothing is known")
        XCTAssertFalse(own.closed.contains(day(2027, 3, 26)), "after the last term nothing is known")
    }

    func testTermsThatMeetLeaveNoGap() {
        let first = SchoolCalendar.Term(name: "Term 1", start: day(2026, 8, 11), end: day(2026, 12, 11))
        let next = SchoolCalendar.Term(name: "Term 2", start: day(2026, 12, 12), end: day(2027, 3, 25))
        XCTAssertEqual(SchoolCalendar(terms: [first, next]).withTermGaps(calendar: calendar).closed, [])
        XCTAssertEqual(SchoolCalendar.none.withTermGaps(calendar: calendar), .none)
    }
}
