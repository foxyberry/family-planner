import Domain
import XCTest

/// A school with its own term dates (spec S2 "Own terms"): the days between one term's end and the
/// next term's start are its holidays, whether or not its list names them. Made-up dates.
final class SchoolCalendarTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return calendar
    }()

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Day { Day(year: year, month: month, day: day) }

    func testTheDaysBetweenTermsAreHolidays() {
        let term1 = SchoolCalendar.Term(name: "Term 1", start: day(2026, 9, 1), end: day(2026, 12, 4))
        let term2 = SchoolCalendar.Term(name: "Term 2", start: day(2027, 1, 4), end: day(2027, 3, 26))
        let midTerm = Set([day(2026, 10, 19), day(2026, 10, 20)])
        let own = SchoolCalendar(terms: [term2, term1], closed: midTerm,
                                 breaks: [day(2026, 10, 19): "Mid-term", day(2026, 10, 20): "Mid-term"])
            .withTermGaps(calendar: calendar)

        XCTAssertTrue(own.closed.contains(day(2026, 12, 5)), "the day after Term 1 ends")
        XCTAssertTrue(own.closed.contains(day(2026, 12, 25)))
        XCTAssertTrue(own.closed.contains(day(2027, 1, 3)), "the day before Term 2 starts")
        XCTAssertFalse(own.closed.contains(day(2026, 12, 4)), "Term 1's last day is a school day")
        XCTAssertFalse(own.closed.contains(day(2027, 1, 4)), "Term 2's first day is a school day")
        XCTAssertEqual(own.closed.filter { $0 >= day(2026, 12, 5) && $0 <= day(2027, 1, 3) }.count, 30)
        XCTAssertEqual(own.breaks[day(2026, 12, 20)], "School holidays")
        XCTAssertEqual(own.breaks[day(2026, 10, 19)], "Mid-term", "a named break keeps its name")
        XCTAssertTrue(own.closed.isSuperset(of: midTerm))
        XCTAssertFalse(own.closed.contains(day(2026, 8, 31)), "before the first term nothing is known")
        XCTAssertFalse(own.closed.contains(day(2027, 3, 27)), "after the last term nothing is known")
    }

    func testTermsThatMeetLeaveNoGap() {
        let first = SchoolCalendar.Term(name: "Term 1", start: day(2026, 9, 1), end: day(2026, 12, 4))
        let next = SchoolCalendar.Term(name: "Term 2", start: day(2026, 12, 5), end: day(2027, 3, 26))
        XCTAssertEqual(SchoolCalendar(terms: [first, next]).withTermGaps(calendar: calendar).closed, [])
        XCTAssertEqual(SchoolCalendar.none.withTermGaps(calendar: calendar), .none)
    }
}
