import Domain
import Foundation
import XCTest

final class DayTests: XCTestCase {
    func testDayFromDateUsesCalendarTimeZone() {
        // 00:30 on 9 Nov in Singapore is still 8 Nov in UTC.
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let date = utc.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 16, minute: 30))!
        XCTAssertEqual(Day(date, calendar: Fixture.calendar), Day(year: 2026, month: 11, day: 9))
    }

    func testWeekdayAndAdding() {
        XCTAssertEqual(Fixture.monday.weekday(Fixture.calendar), .monday)
        XCTAssertEqual(Fixture.monday.adding(days: 5, calendar: Fixture.calendar), Fixture.saturday)
        XCTAssertEqual(Day(year: 2026, month: 12, day: 31).adding(days: 1, calendar: Fixture.calendar),
                       Day(year: 2027, month: 1, day: 1))
    }
}

final class SeriesEditsTests: XCTestCase {
    private typealias F = Fixture

    func testNextOccurrenceTodayIfNotEnded() {
        let swim = F.weekly(start: 930, end: 990)
        let next = SeriesEdits.nextOccurrence(of: swim, from: F.monday, nowMinute: 980, holidays: [],
                                              calendar: F.calendar)
        XCTAssertEqual(next, F.monday)
        let afterEnd = SeriesEdits.nextOccurrence(of: swim, from: F.monday, nowMinute: 990, holidays: [],
                                                  calendar: F.calendar)
        XCTAssertEqual(afterEnd, F.wednesday)
    }

    func testNextOccurrenceSkipsSkippedDaysAndHolidays() {
        var swim = F.weekly()
        swim.skippedDays = [F.monday]
        XCTAssertEqual(SeriesEdits.nextOccurrence(of: swim, from: F.monday, nowMinute: 0,
                                                  holidays: [F.wednesday], calendar: F.calendar),
                       Day(year: 2026, month: 11, day: 16))
    }

    func testSkippingAndUnskipping() {
        let swim = F.weekly()
        let skipped = SeriesEdits.skipping(swim, day: F.monday)
        XCTAssertEqual(skipped.skippedDays, [F.monday])
        XCTAssertEqual(SeriesEdits.unskipping(skipped, day: F.monday).skippedDays, [])
    }

    func testEndingKeepsPastDays() {
        let swim = F.weekly()
        let ended = SeriesEdits.ending(swim, before: F.wednesday, calendar: F.calendar)
        XCTAssertTrue(DayPlanner.occurs(ended, on: F.monday, kid: F.kidA.id, holidays: [], calendar: F.calendar))
        XCTAssertFalse(DayPlanner.occurs(ended, on: F.wednesday, kid: F.kidA.id, holidays: [], calendar: F.calendar))
    }
}

final class FormattingTests: XCTestCase {
    private let calendar = Fixture.calendar

    func testTimeText() {
        XCTAssertEqual(TimeText.clock(930), "3:30")
        XCTAssertEqual(TimeText.clock(0), "12:00")
        XCTAssertEqual(TimeText.clock(420), "7:00")
        XCTAssertEqual(TimeText.withPeriod(930), "3:30 pm")
        XCTAssertEqual(TimeText.withPeriod(0), "12:00 am")
        XCTAssertEqual(TimeText.withPeriod(720), "12:00 pm")
        XCTAssertEqual(TimeText.withPeriod(1440), "12:00 am")
        // A range in one half says am or pm once, at the end; across halves it keeps both.
        XCTAssertEqual(TimeText.range(930, 990), "3:30–4:30 pm")
        XCTAssertEqual(TimeText.range(450, 900), "7:30 am–3:00 pm")
        XCTAssertEqual(TimeText.range(660, 720), "11:00 am–12:00 pm")
        XCTAssertEqual(TimeText.range(1200, 1440), "8:00 pm–12:00 am")
        XCTAssertEqual(TimeText.range(0, 390), "12:00–6:30 am")
    }

    func testDuration() {
        XCTAssertEqual(TimeText.duration(60), "1 hour")
        XCTAssertEqual(TimeText.duration(120), "2 hours")
        XCTAssertEqual(TimeText.duration(90), "1 hr 30 min")
        XCTAssertEqual(TimeText.duration(45), "45 min")
    }

    func testDayText() {
        XCTAssertEqual(DayText.short(Fixture.saturday, calendar: calendar), "Sat 14 Nov")
        XCTAssertEqual(DayText.long(Fixture.saturday, calendar: calendar), "Saturday 14 Nov")
        XCTAssertEqual(DayText.dayMonth(Fixture.monday, calendar: calendar), "9 Nov")
    }

    func testDayLists() {
        XCTAssertEqual(DayText.chips([.wednesday, .monday]), "Mon · Wed")
        XCTAssertEqual(DayText.chips(Weekday.schoolDays), "Every school day")
        XCTAssertEqual(DayText.sentence([.monday]), "Monday")
        XCTAssertEqual(DayText.sentence([.wednesday, .monday]), "Monday and Wednesday")
        XCTAssertEqual(DayText.sentence([.friday, .monday, .wednesday]), "Monday, Wednesday and Friday")
        XCTAssertEqual(DayText.sentence(Weekday.schoolDays), "school day")
    }
}
