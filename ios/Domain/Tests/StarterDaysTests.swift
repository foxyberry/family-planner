import Domain
import XCTest

/// First-run setup gives each kid templates shaped like the seed (spec "Seed data in M2").
final class StarterDaysTests: XCTestCase {
    private let from = Day(year: 2026, month: 1, day: 1)
    private let id = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!

    private func kid(school: School?) -> Kid {
        Kid(id: id, name: "Kid A", colorIndex: 0, age: 8, schoolYear: nil, school: school)
    }

    func testSchoolKidIsAtSchoolFromArriveByWithTheTripAndLockedEdges() throws {
        let school = School(name: "Example Primary School", days: Weekday.schoolDays, start: 450, end: 810,
                            arriveBy: 440)
        let trip = Trip(way: .bus, leaveBefore: 20)
        let routines = StarterDays.routines(for: kid(school: school), trip: trip, from: from)
        XCTAssertEqual(routines.map(\.dayType), [.weekday, .saturday, .sunday])
        let weekday = try XCTUnwrap(routines.first)
        let block = try XCTUnwrap(weekday.blocks.first { $0.kind == .school })
        XCTAssertEqual([block.start, block.end], [440, 810])
        XCTAssertTrue(block.isLocked)
        XCTAssertEqual(block.trip, trip)
        XCTAssertEqual(weekday.blocks.map(\.kind), [.sleep, .morning, .school, .free, .dinner, .evening, .sleep])
    }

    func testPreschoolMakesItsOwnBlock() throws {
        let preschool = School(name: "Example Preschool", days: Weekday.schoolDays, start: 480, end: 720, kind: .preschool)
        let block = try XCTUnwrap(StarterDays.routines(for: kid(school: preschool), trip: Trip(way: .walk, leaveBefore: 10),
                                                       from: from)[0].blocks.first { $0.kind == .school })
        XCTAssertEqual(block.title, "Preschool")
        XCTAssertEqual([block.start, block.end], [480, 720])
        XCTAssertEqual(block.trip?.way, .walk)
    }

    func testLateGraceIsLatestMinusArriveByUpTo30() {
        var school = School(name: "Example Primary School", days: Weekday.schoolDays, start: 450, end: 810,
                            arriveBy: 450, latest: 460)
        XCTAssertEqual(school.lateGrace, 10)
        school.latest = 520
        XCTAssertEqual(school.lateGrace, 30)
        school.latest = nil
        XCTAssertNil(school.lateGrace)
        let plan = BusPlan(kid: id, stop: "00000", services: ["1"], lateGrace: 15)
        school.latest = 455
        XCTAssertEqual(plan.graced(by: kid(school: school)).lateGrace, 5, "the school record wins")
        XCTAssertEqual(plan.graced(by: kid(school: nil)).lateGrace, 15)
    }

    func testTemplatesCoverTheWholeDayWithoutGaps() {
        let school = School(name: "Example Primary School", days: Weekday.schoolDays, start: 360, end: 1140)
        for routine in StarterDays.routines(for: kid(school: school), trip: nil, from: from)
            + StarterDays.routines(for: kid(school: nil), trip: nil, from: from) {
            XCTAssertEqual(routine.blocks.first?.start, 0)
            XCTAssertEqual(routine.blocks.last?.end, 1440)
            for (a, b) in zip(routine.blocks, routine.blocks.dropFirst()) { XCTAssertEqual(a.end, b.start) }
        }
    }

    func testKidAtHomeHasOneDayAllWeek() {
        let routines = StarterDays.routines(for: kid(school: nil), trip: nil, from: from)
        XCTAssertEqual(routines.count, 3)
        XCTAssertEqual(Set(routines.map(\.blocks)).count, 1)
        XCTAssertFalse(routines[0].blocks.contains { $0.kind == .school })
    }

    func testMissions() {
        var n = 0
        let next = { () -> UUID in n += 1; return UUID(uuidString: "00000000-0000-4000-8000-" + String(format: "%012d", n))! }
        let school = School(name: "Example Primary School", days: Weekday.schoolDays, start: 450, end: 810)
        XCTAssertEqual(StarterDays.missions(for: kid(school: school), id: next).map(\.picture),
                       ["sun", "toothbrush", "shirt", "actBreakfast", "backpack", "shoe"])
        XCTAssertEqual(StarterDays.missions(for: kid(school: nil), id: next).map(\.order), [0, 1, 2])
    }
}
