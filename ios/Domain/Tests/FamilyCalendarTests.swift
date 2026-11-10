import Domain
import XCTest

/// Spec "Repeats, dates and changes": each kid's days off, an item's for its audience, and
/// "End of term" runs worked out from the school calendar.
final class FamilyCalendarTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return calendar
    }()
    private let kidA = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
    private let kidB = UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!
    private let monday = Day(year: 2026, month: 11, day: 23)
    private let tuesday = Day(year: 2026, month: 11, day: 24)
    private let term4 = SchoolCalendar.Term(name: "Term 4", start: Day(year: 2026, month: 9, day: 14),
                                            end: Day(year: 2026, month: 11, day: 20))

    private var family: FamilyCalendar {
        FamilyCalendar(schools: [kidA: SchoolCalendar(terms: [term4], closed: [monday]), kidB: .none],
                       publicHolidays: [tuesday])
    }

    func testDaysOffPerKidAndForBoth() {
        XCTAssertEqual(family.daysOff(kidA), [monday, tuesday])
        XCTAssertEqual(family.daysOff(kidB), [tuesday])
        XCTAssertEqual(family.daysOff(for: .both), [tuesday], "both kids: only the days off for both")
    }

    func testEndOfTermRunsEndOnTheTermsLastDay() {
        let swimming = ScheduleItem(id: UUID(), title: "Swimming", iconName: "actSwim", audience: .kid(kidA),
                                    start: 930, end: 990,
                                    recurrence: .weekly([.monday], from: Day(year: 2026, month: 11, day: 2), until: nil),
                                    skippedDays: [], skipsHolidays: true, showsStar: false, runsEnd: .term)
        let resolved = family.resolving([swimming], calendar: calendar).first
        XCTAssertEqual(resolved?.recurrence, .weekly([.monday], from: Day(year: 2026, month: 11, day: 2), until: term4.end))
        var noTerm = swimming
        noTerm.audience = .kid(kidB)
        XCTAssertEqual(family.resolving([noTerm], calendar: calendar).first?.recurrence, noTerm.recurrence, "no calendar: no end")
    }

    func testAfterNTimesEndsOnTheNthDayItHappensSkippingDaysOff() {
        // Mondays from 2 Nov: 9, 16 Nov happen; 23 Nov is Kid A's school holiday (skipped); 30 Nov.
        let swimming = ScheduleItem(id: UUID(), title: "Swimming", iconName: "actSwim", audience: .kid(kidA),
                                    start: 930, end: 990,
                                    recurrence: .weekly([.monday], from: Day(year: 2026, month: 11, day: 2), until: nil),
                                    skippedDays: [], skipsHolidays: true, showsStar: false, runsEnd: .count(4))
        let resolved = family.resolving([swimming], calendar: calendar).first
        XCTAssertEqual(resolved?.recurrence,
                       .weekly([.monday], from: Day(year: 2026, month: 11, day: 2), until: Day(year: 2026, month: 11, day: 30)))
    }

    func testASchoolCalendarsTermEnd() {
        let year = SchoolCalendar(terms: [term4], closed: [monday])
        XCTAssertEqual(year.termEnd(from: Day(year: 2026, month: 10, day: 1)), term4.end)
        XCTAssertNil(year.termEnd(from: monday), "no term after the last one")
    }
}
