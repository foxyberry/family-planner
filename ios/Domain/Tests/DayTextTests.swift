import Domain
import Foundation
import XCTest

final class DayTextTests: XCTestCase {
    private typealias F = Fixture

    func testMinuteOfDayInTheCalendarsTimeZone() {
        XCTAssertEqual(Day.minute(of: F.monday.date(minute: 0, calendar: F.calendar), calendar: F.calendar), 0)
        XCTAssertEqual(Day.minute(of: F.monday.date(minute: 930, calendar: F.calendar), calendar: F.calendar), 930)
        XCTAssertEqual(Day.minute(of: F.monday.date(minute: 1439, calendar: F.calendar), calendar: F.calendar), 1439)
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        // 3:30 pm in Singapore is 7:30 am in UTC.
        XCTAssertEqual(Day.minute(of: F.monday.date(minute: 930, calendar: F.calendar), calendar: utc), 450)
    }

    func testInitialIsTheFirstLetter() {
        XCTAssertEqual(Weekday.allCases.sorted().map(DayText.initial), ["M", "T", "W", "T", "F", "S", "S"])
    }

    func testEveryTitle() {
        XCTAssertEqual(DayText.every([.monday]), "Every Mon")
        XCTAssertEqual(DayText.every([.wednesday, .monday]), "Every Mon and Wed")
        XCTAssertEqual(DayText.every([.friday, .monday, .wednesday]), "Every Mon, Wed and Fri")
        XCTAssertEqual(DayText.every([.sunday, .saturday]), "Every Sat and Sun")
        XCTAssertEqual(DayText.every(Weekday.schoolDays), "Every school day")
    }

    func testSentenceStillReadsLongNames() {
        XCTAssertEqual(DayText.sentence([.monday, .wednesday, .friday]), "Monday, Wednesday and Friday")
        XCTAssertEqual(DayText.sentence(Weekday.schoolDays), "school day")
    }

    func testMondayOfWeek() {
        let sunday = Day(year: 2026, month: 11, day: 15)
        XCTAssertEqual(sunday.mondayOfWeek(calendar: F.calendar), Day(year: 2026, month: 11, day: 9))
        XCTAssertEqual(Day(year: 2026, month: 11, day: 9).mondayOfWeek(calendar: F.calendar), Day(year: 2026, month: 11, day: 9))
    }
}
