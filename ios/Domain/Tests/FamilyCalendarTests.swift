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

    /// Spec "Hub text" and K1 "Marks": a public holiday's name, a kid's break and its name. Bundled
    /// 2026 data: the March holidays run 14–22 Mar with Hari Raya Puasa on the 21st inside them;
    /// Labour Day (1 May) is outside any break.
    func testHolidayAndBreakNames() {
        let march16 = Day(year: 2026, month: 3, day: 16), raya = Day(year: 2026, month: 3, day: 21)
        let labourDay = Day(year: 2026, month: 5, day: 1), school = Day(year: 2026, month: 3, day: 12)
        let breaks = [march16: "March holidays", raya: "March holidays"]
        let year = FamilyCalendar(schools: [kidA: SchoolCalendar(closed: [march16, raya, labourDay], breaks: breaks),
                                            kidB: .none],
                                  publicHolidays: [raya, labourDay],
                                  holidayNames: [raya: "Hari Raya Puasa", labourDay: "Labour Day", school: "Not a holiday"])
        XCTAssertEqual(year.holidayName(on: labourDay), "Labour Day")
        XCTAssertEqual(year.holidayName(on: raya), "Hari Raya Puasa")
        XCTAssertNil(year.holidayName(on: school), "a name for a day that is not in the holiday list")
        XCTAssertNil(year.holidayName(on: march16))
        XCTAssertEqual(year.breakName(kidA, on: march16), "March holidays")
        XCTAssertEqual(year.breakName(kidA, on: raya), "March holidays", "a public holiday inside a break keeps it")
        XCTAssertNil(year.breakName(kidA, on: labourDay), "a public holiday alone is no break")
        XCTAssertNil(year.breakName(kidA, on: school))
        XCTAssertNil(year.breakName(kidB, on: march16), "a kid at home has no breaks")
        XCTAssertEqual(year.breakDays(kidA), [march16, raya])
        XCTAssertEqual(year.breakDays(kidB), [])
        XCTAssertEqual(year.daysOff(kidA), [march16, raya, labourDay], "days off are unchanged")
    }

    /// User, 2026-11-28: the day off in lieu of a Sunday holiday reads as the holiday itself, without
    /// the list's "(observed)".
    func testAnObservedHolidayReadsAsItsName() {
        let monday = Day(year: 2026, month: 6, day: 1)
        let year = FamilyCalendar(publicHolidays: [monday], holidayNames: [monday: "Vesak Day (observed)"])
        XCTAssertEqual(year.holidayName(on: monday), "Vesak Day")
    }

    func testASchoolCalendarsTermEnd() {
        let year = SchoolCalendar(terms: [term4], closed: [monday])
        XCTAssertEqual(year.termEnd(from: Day(year: 2026, month: 10, day: 1)), term4.end)
        XCTAssertNil(year.termEnd(from: monday), "no term after the last one")
    }
}
