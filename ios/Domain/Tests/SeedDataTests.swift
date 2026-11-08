import Domain
import XCTest

/// The seed matches the design boards (spec "Seed data in M2"): A1 on a Monday, E3 on a Saturday.
final class SeedDataTests: XCTestCase {
    private let calendar = Fixture.calendar
    /// The seed is written on Sunday 8 Nov 2026; the week under test follows it.
    private let seedDay = Day(year: 2026, month: 11, day: 8)

    private func slots(_ kid: Kid, on day: Day, holidays: Set<Day> = []) -> [Slot] {
        DayPlanner.slots(on: day, kid: kid, routines: SeedData.routines,
                         items: SeedData.items(today: seedDay, calendar: calendar), holidays: holidays,
                         calendar: calendar)
    }

    private func spans(_ slots: [Slot], from: Int, to: Int) -> [String] {
        slots.filter { $0.end > from && $0.start < to }.map { "\($0.title) \($0.start)-\($0.end)" }
    }

    func testSeedVersionIsTwo() {
        XCTAssertEqual(SeedData.version, 2)
    }

    func testMondayAt652IsBreakfastUntil730() {
        let now = DayPlanner.now(at: 412, in: slots(SeedData.kidA, on: Fixture.monday))
        XCTAssertEqual(now.current?.title, "Breakfast")
        XCTAssertEqual(now.current?.end, 450)
        XCTAssertEqual(now.next?.title, "School")
    }

    func testSchoolIsLockedFrom730To1500() {
        let school = SeedData.routines.first { $0.kid == SeedData.kidA.id && $0.dayType == .weekday }?
            .blocks.first { $0.kind == .school }
        XCTAssertEqual(school?.start, 450)
        XCTAssertEqual(school?.end, 900)
        XCTAssertEqual(school?.isLocked, true)
    }

    func testMondayAfterSchoolShowsSnackSwimmingFree() {
        XCTAssertEqual(spans(slots(SeedData.kidA, on: Fixture.monday), from: 900, to: 1020),
                       ["Snack 900-930", "Swimming 930-990", "Free time 990-1020"])
    }

    func testFreeTimeHasNoPicture() {
        let free = slots(SeedData.kidA, on: Fixture.tuesday).first { $0.kind == .free }
        XCTAssertEqual(free?.start, 960)
        XCTAssertEqual(free?.end, 1020)
        XCTAssertEqual(free?.iconName, "")
    }

    func testFridayHasArtClubAfterSchool() {
        let friday = Day(year: 2026, month: 11, day: 13)
        XCTAssertEqual(spans(slots(SeedData.kidA, on: friday), from: 900, to: 960), ["Art club 900-960"])
    }

    func testSaturdayAt915IsWeekendSchoolUntilNoon() {
        let saturday = slots(SeedData.kidA, on: Fixture.saturday)
        let now = DayPlanner.now(at: 555, in: saturday)
        XCTAssertEqual(now.current?.title, "Weekend school")
        XCTAssertEqual(now.current?.iconName, "actLanguageSchool")
        XCTAssertEqual(now.current?.end, 720)
        XCTAssertEqual(spans(saturday, from: 840, to: 960), ["Birthday 840-960"])
        XCTAssertEqual(saturday.first { $0.title == "Birthday" }?.showsStar, true)
    }

    func testWeekendShapeIsTheSameOnSaturdayAndSunday() {
        let expected = ["Sleep 0-450", "Breakfast 450-510", "Play 510-1140", "Dinner 1140-1215",
                        "Shower 1215-1245", "Sleep 1245-1440"]
        XCTAssertEqual(spans(slots(SeedData.kidA, on: Fixture.sunday), from: 0, to: 1440), expected)
    }

    func testWeekdayHolidayHidesSwimming() {
        let holiday = slots(SeedData.kidA, on: Fixture.monday, holidays: [Fixture.monday])
        XCTAssertNil(holiday.first { $0.title == "Swimming" })
        XCTAssertNil(holiday.first { $0.kind == .school }, "a weekday holiday uses the Sun template")
    }

    func testSaturdayHolidayKeepsWeekendSchool() {
        let holiday = slots(SeedData.kidA, on: Fixture.saturday, holidays: [Fixture.saturday])
        XCTAssertNotNil(holiday.first { $0.title == "Weekend school" })
    }

    func testKidBNapsAndSleepsAt730pm() {
        for day in [Fixture.monday, Fixture.sunday] {
            let kidB = slots(SeedData.kidB, on: day)
            XCTAssertEqual(kidB.first?.end, 390, "wakes at 6:30")
            XCTAssertEqual(kidB.first { $0.title == "Nap" }.map { [$0.start, $0.end] }, [780, 900])
            XCTAssertEqual(kidB.last?.start, 1170, "bed at 19:30")
        }
        // On the seed Saturday the Birthday (14:00, both kids) wins over the rest of the nap.
        let saturday = slots(SeedData.kidB, on: Fixture.saturday)
        XCTAssertEqual(saturday.first { $0.title == "Nap" }.map { [$0.start, $0.end] }, [780, 840])
        XCTAssertEqual(saturday.first { $0.title == "Birthday" }.map { [$0.start, $0.end] }, [840, 960])
    }

    func testEveryTemplateCoversTheWholeDay() {
        for routine in SeedData.routines {
            let blocks = routine.blocks.sorted { $0.start < $1.start }
            XCTAssertEqual(blocks.first?.start, 0)
            XCTAssertEqual(blocks.last?.end, 1440)
            for (a, b) in zip(blocks, blocks.dropFirst()) {
                XCTAssertEqual(a.end, b.start, "\(routine.dayType) \(a.title) → \(b.title)")
            }
            XCTAssertEqual(routine.blocks.filter(\.isLocked).map(\.kind).allSatisfy { $0 == .school }, true)
        }
    }

    func testSeedIsFakeAndComplete() {
        XCTAssertEqual(SeedData.kids.map(\.name), ["Kid A", "Kid B"])
        XCTAssertEqual(SeedData.kidA.school?.name, "Example Primary School")
        XCTAssertNil(SeedData.kidB.school)
        for kid in SeedData.kids {
            for type in DayType.allCases {
                XCTAssertTrue(SeedData.routines.contains { $0.kid == kid.id && $0.dayType == type }, "\(kid.name) \(type)")
            }
        }
        let items = SeedData.items(today: Fixture.monday, calendar: Fixture.calendar)
        XCTAssertEqual(items.filter { if case .weekly = $0.recurrence { $0.audience == .kid(SeedData.kidA.id) } else { false } }.count, 3)
        XCTAssertTrue(items.contains { if case .once = $0.recurrence { $0.audience == .both } else { false } })
    }

    func testSeedIsStableAcrossLaunches() {
        XCTAssertEqual(SeedData.kidA.id, SeedData.kidA.id)
        XCTAssertEqual(SeedData.items(today: Fixture.monday, calendar: Fixture.calendar).map(\.id),
                       SeedData.items(today: Fixture.monday, calendar: Fixture.calendar).map(\.id))
    }
}
