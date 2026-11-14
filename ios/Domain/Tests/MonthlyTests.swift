import Domain
import XCTest

/// Board C3m (layout v39): every month on the "2nd Sat" or on "Day 14"; a month without that day
/// skips it. Made-up items only.
final class MonthlyTests: XCTestCase {
    private let kid = UUID()

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return calendar
    }

    private func item(_ rule: MonthlyRule, from: Day, until: Day? = nil) -> ScheduleItem {
        ScheduleItem(id: UUID(), title: "Library visit", iconName: "actStory", audience: .both, start: 600, end: 660,
                     recurrence: .monthly(rule, from: from, until: until), skippedDays: [], skipsHolidays: false,
                     showsStar: false)
    }

    func testTheRuleFromAFirstDate() {
        let saturday = Day(year: 2026, month: 11, day: 14)
        XCTAssertEqual(MonthlyRule.nthWeekday(of: saturday, calendar: calendar), .nthWeekday(2, .saturday))
        XCTAssertEqual(DayText.monthly(.nthWeekday(2, .saturday)), "2nd Sat")
        XCTAssertEqual(DayText.monthly(.dayOfMonth(14)), "Day 14")
        // Board G2m's heading.
        XCTAssertEqual(DayText.monthlyEvery(.nthWeekday(2, .saturday)), "Every 2nd Sat")
        XCTAssertEqual(DayText.monthlyEvery(.dayOfMonth(14)), "Every 14th")
        XCTAssertEqual([1, 2, 3, 11, 12, 13, 21, 22, 23, 31].map(DayText.ordinal),
                       ["1st", "2nd", "3rd", "11th", "12th", "13th", "21st", "22nd", "23rd", "31st"])
    }

    func testTheSecondSaturdayOfEveryMonth() {
        let monthly = item(.nthWeekday(2, .saturday), from: Day(year: 2026, month: 11, day: 14))
        let days = [Day(year: 2026, month: 11, day: 14), Day(year: 2026, month: 12, day: 12),
                    Day(year: 2027, month: 1, day: 9)]
        for day in days {
            XCTAssertTrue(DayPlanner.occurs(monthly, on: day, kid: kid, holidays: [], calendar: calendar), "\(day)")
        }
        XCTAssertFalse(DayPlanner.occurs(monthly, on: Day(year: 2026, month: 12, day: 5), kid: kid, holidays: [], calendar: calendar))
        XCTAssertFalse(DayPlanner.occurs(monthly, on: Day(year: 2026, month: 10, day: 10), kid: kid, holidays: [], calendar: calendar),
                       "not before its first date")
    }

    func testAMonthWithoutThatDaySkipsIt() {
        let fifth = item(.nthWeekday(5, .saturday), from: Day(year: 2026, month: 10, day: 31))
        // November 2026 has four Saturdays; January 2027 has a fifth (the 30th).
        let november = (1...30).map { Day(year: 2026, month: 11, day: $0) }
        XCTAssertFalse(november.contains { DayPlanner.occurs(fifth, on: $0, kid: kid, holidays: [], calendar: self.calendar) })
        XCTAssertTrue(DayPlanner.occurs(fifth, on: Day(year: 2027, month: 1, day: 30), kid: kid, holidays: [], calendar: calendar))
        let thirtyFirst = item(.dayOfMonth(31), from: Day(year: 2026, month: 10, day: 31))
        XCTAssertFalse(DayPlanner.occurs(thirtyFirst, on: Day(year: 2026, month: 11, day: 30), kid: kid, holidays: [],
                                          calendar: calendar))
        XCTAssertTrue(DayPlanner.occurs(thirtyFirst, on: Day(year: 2026, month: 12, day: 31), kid: kid, holidays: [],
                                         calendar: calendar))
    }

    func testEndingAndSplittingKeepTheRule() {
        let monthly = item(.dayOfMonth(14), from: Day(year: 2026, month: 11, day: 14))
        let ended = SeriesEdits.ending(monthly, before: Day(year: 2027, month: 1, day: 1), calendar: calendar)
        XCTAssertEqual(ended.recurrence, .monthly(.dayOfMonth(14), from: Day(year: 2026, month: 11, day: 14),
                                                  until: Day(year: 2026, month: 12, day: 31)))
        var edit = monthly
        edit.start = 630
        let split = SeriesEdits.splitting(monthly, with: edit, from: Day(year: 2027, month: 1, day: 1), newID: UUID(),
                                          calendar: calendar)
        XCTAssertEqual(split.items.count, 2)
        XCTAssertEqual(split.items[1].recurrence.range?.from, Day(year: 2027, month: 1, day: 1))
        XCTAssertTrue(split.items[1].isMonthly)
    }

    func testOldItemsStillDecode() throws {
        let monthly = item(.nthWeekday(2, .saturday), from: Day(year: 2026, month: 11, day: 14))
        let copy = try JSONDecoder().decode(ScheduleItem.self, from: JSONEncoder().encode(monthly))
        XCTAssertEqual(copy, monthly)
        XCTAssertTrue(copy.isRepeating)
    }
}
