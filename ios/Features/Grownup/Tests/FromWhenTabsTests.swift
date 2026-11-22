import Domain
import Foundation
import Grownup
import XCTest

/// Board G5 (layout v69): the middle tab names the day ("Tomorrow" or "Wed 18 Nov", never
/// "Next Wed"), is hidden without a day in the next 14 days, and the card opens on the day shown.
final class FromWhenTabsTests: XCTestCase {
    private typealias F = Fixture
    private let tuesday = Day(year: 2026, month: 11, day: 10)

    private func day(_ number: Int) -> Day { Day(year: 2026, month: 11, day: number) }

    func testTheMiddleTabIsTomorrowWhenItIsTomorrow() {
        let tabs = FromWhenTabs.tabs(next: day(11), today: tuesday, calendar: F.calendar)
        XCTAssertEqual(tabs.map(\.0), [.today, .next, .date])
        XCTAssertEqual(tabs.map(\.1), ["Today", "Tomorrow", "Date"])
    }

    func testALaterMiddleDayReadsAsItsShortDate() {
        XCTAssertEqual(FromWhenTabs.tabs(next: day(18), today: tuesday, calendar: F.calendar).map(\.1),
                       ["Today", "Wed 18 Nov", "Date"])
        XCTAssertEqual(FromWhenTabs.tabs(next: day(12), today: tuesday, calendar: F.calendar).map(\.1),
                       ["Today", "Thu 12 Nov", "Date"], "the day after tomorrow is a date")
    }

    func testNoMiddleDayHidesTheMiddleTab() {
        let tabs = FromWhenTabs.tabs(next: nil, today: tuesday, calendar: F.calendar)
        XCTAssertEqual(tabs.map(\.0), [.today, .date])
        XCTAssertEqual(tabs.map(\.1), ["Today", "Date"])
    }

    /// The middle day is the first day after today the series has, at most 14 days ahead.
    func testTheNextDayLooksFourteenDaysAhead() {
        XCTAssertEqual(FromWhenTabs.nextDay(after: tuesday, calendar: F.calendar) { _ in true }, day(11),
                       "never today")
        XCTAssertEqual(FromWhenTabs.nextDay(after: tuesday, calendar: F.calendar) { $0 == self.day(24) }, day(24),
                       "14 days ahead still counts")
        XCTAssertNil(FromWhenTabs.nextDay(after: tuesday, calendar: F.calendar) { $0 == self.day(25) },
                     "15 days ahead is too far")
    }

    /// Spec G5 "It opens on the day being looked at": a later day opens on the middle tab when it is
    /// that day, else on Date with that date; today, an earlier day or no day open on Today.
    func testTheCardOpensOnTheDayBeingLookedAt() {
        func open(_ shown: Day?, next: Day?) -> String {
            let opening = FromWhenTabs.opening(shown: shown, next: next, today: tuesday)
            return "\(opening.choice) \(opening.date.day)"
        }
        XCTAssertEqual(open(day(11), next: day(11)), "next 11")
        XCTAssertEqual(open(day(18), next: day(11)), "date 18")
        XCTAssertEqual(open(day(18), next: nil), "date 18", "no middle tab: Date")
        XCTAssertEqual(open(tuesday, next: day(11)), "today 10")
        XCTAssertEqual(open(day(9), next: day(11)), "today 10", "never before today")
        XCTAssertEqual(open(nil, next: day(11)), "today 10", "from the List")
    }
}
