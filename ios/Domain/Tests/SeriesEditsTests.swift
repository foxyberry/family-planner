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

    func testApplyingEditSplitsWhenRunningToday() {
        let swim = F.weekly(start: 930, end: 990)
        var edit = swim
        edit.start = 960
        edit.end = 1020
        let result = SeriesEdits.applying(edit: edit, to: swim, today: F.monday, nowMinute: 945, newID: UUID(), holidays: [],
                                          calendar: F.calendar)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].id, swim.id)
        XCTAssertEqual(result[0].start, 930, "today keeps the old times")
        XCTAssertEqual(result[0].recurrence, .weekly([.monday, .wednesday], from: Day(year: 2026, month: 11, day: 1),
                                                     until: F.monday))
        XCTAssertNotEqual(result[1].id, swim.id)
        XCTAssertEqual(result[1].start, 960)
        XCTAssertEqual(result[1].recurrence, .weekly([.monday, .wednesday], from: F.tuesday, until: nil))
    }

    func testApplyingEditSplitsWhenAlreadyFinishedToday() {
        let swim = F.weekly(start: 930, end: 990)
        var edit = swim
        edit.title = "Swim club"
        let result = SeriesEdits.applying(edit: edit, to: swim, today: F.monday, nowMinute: 1200, newID: UUID(), holidays: [],
                                          calendar: F.calendar)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].title, "Swimming")
    }

    func testApplyingEditMovesFutureSkipsToNewSeries() {
        var swim = F.weekly()
        let nextWeek = Day(year: 2026, month: 11, day: 16)
        let lastWeek = Day(year: 2026, month: 11, day: 2)
        swim.skippedDays = [lastWeek, nextWeek]
        let result = SeriesEdits.applying(edit: swim, to: swim, today: F.monday, nowMinute: 945, newID: UUID(), holidays: [],
                                          calendar: F.calendar)
        XCTAssertEqual(result[0].skippedDays, [lastWeek])
        XCTAssertEqual(result[1].skippedDays, [nextWeek])
    }

    func testApplyingEditInPlaceWhenNotStarted() {
        let swim = F.weekly(start: 930, end: 990)
        var edit = swim
        edit.start = 960
        let notToday = SeriesEdits.applying(edit: edit, to: swim, today: F.tuesday, nowMinute: 945, newID: UUID(), holidays: [],
                                            calendar: F.calendar)
        XCTAssertEqual(notToday, [edit])
        let beforeStart = SeriesEdits.applying(edit: edit, to: swim, today: F.monday, nowMinute: 900, newID: UUID(), holidays: [],
                                               calendar: F.calendar)
        XCTAssertEqual(beforeStart, [edit])
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

final class SeedDataTests: XCTestCase {
    func testSeedIsFakeAndComplete() {
        XCTAssertEqual(SeedData.kids.map(\.name), ["Kid A", "Kid B"])
        XCTAssertEqual(SeedData.kidA.school?.name, "Example Primary School")
        XCTAssertNil(SeedData.kidB.school)
        for kid in SeedData.kids {
            for kind in [DayKind.schoolDay, .dayOff] {
                XCTAssertTrue(SeedData.routines.contains { $0.kid == kid.id && $0.dayKind == kind }, "\(kid.name) \(kind)")
            }
        }
        let items = SeedData.items(today: Fixture.monday, calendar: Fixture.calendar)
        XCTAssertEqual(items.filter { if case .weekly = $0.recurrence { $0.audience == .kid(SeedData.kidA.id) } else { false } }.count, 2)
        XCTAssertTrue(items.contains { if case .once = $0.recurrence { $0.audience == .both } else { false } })
    }

    func testSeedIsStableAcrossLaunches() {
        XCTAssertEqual(SeedData.kidA.id, SeedData.kidA.id)
        XCTAssertEqual(SeedData.items(today: Fixture.monday, calendar: Fixture.calendar).map(\.id),
                       SeedData.items(today: Fixture.monday, calendar: Fixture.calendar).map(\.id))
    }
}
