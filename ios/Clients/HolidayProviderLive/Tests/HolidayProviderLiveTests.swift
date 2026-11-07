import Domain
import HolidayProvider
import HolidayProviderLive
import XCTest

final class HolidayProviderLiveTests: XCTestCase {
    private let provider = HolidayProvider.live

    func testBundledYearsHaveHolidays() async {
        let y2026 = await provider.holidays(2026)
        let y2027 = await provider.holidays(2027)
        XCTAssertGreaterThanOrEqual(y2026.count, 10)
        XCTAssertGreaterThanOrEqual(y2027.count, 10)
        XCTAssertTrue(y2026.allSatisfy { $0.day.year == 2026 })
    }

    func testNationalDay2026AndObservedMonday() async {
        let days = Set(await provider.holidays(2026).map(\.day))
        XCTAssertTrue(days.contains(Day(year: 2026, month: 8, day: 9)))
        XCTAssertTrue(days.contains(Day(year: 2026, month: 8, day: 10)))
    }

    func testChristmas2026() async {
        let christmas = await provider.holidays(2026).first { $0.day == Day(year: 2026, month: 12, day: 25) }
        XCTAssertEqual(christmas?.name, "Christmas Day")
    }

    func testUnknownYearIsEmpty() async {
        let none = await provider.holidays(2030)
        XCTAssertEqual(none, [])
    }
}
