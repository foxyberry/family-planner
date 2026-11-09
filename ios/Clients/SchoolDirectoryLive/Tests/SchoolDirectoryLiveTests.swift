import Dependencies
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

    // MARK: School calendars (spec "Repeats, dates and changes")

    private func calendar(_ school: School, age: Int = 8) async -> SchoolCalendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return await withDependencies { $0.calendar = calendar } operation: {
            await SchoolDirectory.live.calendar(school, age)
        }
    }

    private func school(id: String?, moeTerms: Bool? = nil, kind: SchoolKind? = nil) -> School {
        School(name: "Example School", days: Weekday.schoolDays, start: 450, end: 810, directoryID: id, // copy-ok: test data
               usesMoeTerms: moeTerms, kind: kind)
    }

    func testAnMoePrimarySchoolFollowsThePrimaryCalendar() async throws {
        let schools = await SchoolDirectory.live.schools()
        let primary = try XCTUnwrap(schools.first { if case .moe(.primary) = $0.kind { true } else { false } })
        let year = await calendar(school(id: primary.id))
        XCTAssertEqual(year.terms.count, 8, "four terms in 2026 and 2027")
        XCTAssertEqual(year.termEnd(from: Day(year: 2026, month: 11, day: 10)), Day(year: 2026, month: 11, day: 20))
        XCTAssertEqual(year.termEnd(from: Day(year: 2026, month: 12, day: 1)), Day(year: 2027, month: 3, day: 12),
                       "in the year-end break: the next term's end")
        for closed in [Day(year: 2026, month: 6, day: 1), Day(year: 2026, month: 9, day: 4),
                       Day(year: 2026, month: 3, day: 23), Day(year: 2026, month: 11, day: 23)] {
            XCTAssertTrue(year.closed.contains(closed), "\(closed)")
        }
        XCTAssertFalse(year.closed.contains(Day(year: 2026, month: 11, day: 10)), "a school day")
    }

    func testMoeTermsByHandAndNoCalendar() async {
        let byHand = await calendar(school(id: nil, moeTerms: true))
        XCTAssertTrue(byHand.closed.contains(Day(year: 2026, month: 6, day: 1)), "a typed school using MOE terms")
        let preschool = await calendar(school(id: nil, moeTerms: true, kind: .preschool))
        XCTAssertEqual(preschool.terms.first?.start, Day(year: 2026, month: 1, day: 2), "MOE kindergarten terms")
        let neither = await calendar(school(id: nil))
        XCTAssertEqual(neither, .none, "neither: public holidays only")
    }
}
