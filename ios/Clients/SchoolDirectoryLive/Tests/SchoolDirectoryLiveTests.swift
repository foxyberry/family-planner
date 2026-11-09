import Domain
import SchoolDirectory
import SchoolDirectoryLive
import XCTest

/// The bundled open-data lists decode (counts from Resources/SOURCE.md, data version 2026.11.09).
final class SchoolDirectoryLiveTests: XCTestCase {
    func testEveryMoeSchoolLoadsWithItsLevel() async {
        let moe = await SchoolDirectory.live.schools().filter { if case .moe = $0.kind { true } else { false } }
        XCTAssertEqual(moe.count, 337)
        XCTAssertEqual(moe.filter(\.hasPrimary).count, 182)
        XCTAssertTrue(moe.allSatisfy { $0.followsMoeTerms == true && $0.area != nil })
    }

    /// Only hours a school website states: 16 found and 4 partial in the checked sample.
    func testHoursComeOnlyFromCheckedSchools() async {
        let withHours = await SchoolDirectory.live.schools().filter { $0.hours != nil && { if case .moe = $0.kind { true } else { false } }($0) }
        XCTAssertEqual(withHours.count, 20)
        XCTAssertTrue(withHours.allSatisfy { ($0.hours?.start ?? 0) >= 6 * 60 && ($0.hours?.start ?? 0) <= 10 * 60 })
        XCTAssertTrue(withHours.allSatisfy { $0.hours?.checked == Day(year: 2026, month: 11, day: 9) })
    }

    /// Some checked schools differ by weekday (an early Wednesday, a later Monday start); those days
    /// are kept so the app can store per-day hours (spec S2).
    func testWeekdaysThatDifferAreKept() async {
        let schools = await SchoolDirectory.live.schools()
        let varying = schools.filter { !($0.hours?.byWeekday.isEmpty ?? true) }
        XCTAssertGreaterThan(varying.count, 0)
        for school in varying {
            for (weekday, day) in school.hours?.byWeekday ?? [:] {
                XCTAssertEqual(day.weekday, weekday)
                XCTAssertLessThan(day.start, day.end, school.id)
            }
        }
    }

    func testTheLicencesNoticesAreThere() async {
        let sources = await SchoolDirectory.live.sources()
        XCTAssertEqual(sources.count, 2)
        XCTAssertTrue(sources[0].attribution.contains("data.gov.sg"))
        XCTAssertTrue(sources[1].licenceURL.contains("onemap"))
    }

    func testSearchFindsBySearchKeys() async {
        let schools = await SchoolDirectory.live.schools()
        let first = try? XCTUnwrap(schools.first { $0.hasPrimary })
        guard let first else { return }
        XCTAssertEqual(SchoolSearch.matches(first.name, in: schools).first?.id, first.id)
    }
}
