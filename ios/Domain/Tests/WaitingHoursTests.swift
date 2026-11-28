import Domain
import Foundation
import XCTest

/// Spec G5 "What Settings shows meanwhile": a School Every time change from a later day waits beside
/// the record (one per kid's school) until its day, like the waiting school move.
final class WaitingHoursTests: XCTestCase {
    private typealias F = Fixture

    private func day(_ number: Int) -> Day { Day(year: 2026, month: 11, day: number) }

    private var later: School {
        var school = F.kidA.school!
        school.start = 510
        school.end = 840
        return school
    }

    func testASaveFromALaterDayWaitsAndKeepsTodaysHours() {
        let kid = F.kidA.savingSchool(later, from: day(18), today: F.tuesday)
        XCTAssertEqual(kid.school, F.kidA.school, "today's hours stay in force")
        XCTAssertEqual(kid.pendingHours, PendingHours(school: later, from: day(18)))
    }

    func testASaveFromTodayIsTheRecordAndDropsTheWaitingChange() {
        let waiting = F.kidA.savingSchool(later, from: day(18), today: F.tuesday)
        var now = later
        now.end = 870
        let kid = waiting.savingSchool(now, from: F.tuesday, today: F.tuesday)
        XCTAssertEqual(kid.school, now)
        XCTAssertNil(kid.pendingHours)
    }

    func testASecondSaveReplacesTheWaitingChange() {
        let first = F.kidA.savingSchool(later, from: day(18), today: F.tuesday)
        var again = later
        again.end = 780
        let second = first.savingSchool(again, from: day(20), today: F.tuesday)
        XCTAssertEqual(second.pendingHours, PendingHours(school: again, from: day(20)), "one waiting change")
        XCTAssertEqual(second.school, F.kidA.school)
    }

    /// The waiting hours are the record from their own day on, not before.
    func testWaitingHoursBecomeTheRecordOnTheirDay() {
        let kid = F.kidA.savingSchool(later, from: day(18), today: F.tuesday)
        XCTAssertEqual(kid.applyingWaitingChanges(on: day(17)), kid)
        let after = kid.applyingWaitingChanges(on: day(18))
        XCTAssertEqual(after.school, later)
        XCTAssertNil(after.pendingHours)
    }

    /// A school move replaces the whole record: the old school's waiting hours go with it.
    func testASchoolMoveOnItsDayDropsTheOldSchoolsWaitingHours() {
        var kid = F.kidA.savingSchool(later, from: day(25), today: F.tuesday)
        let next = School(name: "Example Secondary School", days: Weekday.schoolDays, start: 450, end: 870)
        kid.pendingSchool = PendingSchool(school: next, from: day(18))
        let moved = kid.applyingWaitingChanges(on: day(18))
        XCTAssertEqual(moved.school, next)
        XCTAssertNil(moved.pendingSchool)
        XCTAssertNil(moved.pendingHours)
        XCTAssertEqual(moved.applyingWaitingChanges(on: day(25)).school, next, "never applied to the new school")
    }

    /// Kids stored before waiting hours existed load with none.
    func testAKidStoredWithoutWaitingHoursDecodes() throws {
        let json = #"{"id":"\#(F.kidA.id)","name":"Kid A","colorIndex":0,"age":8,"#
            + #""school":{"name":"Example Primary School","days":[2,3,4,5,6],"start":480,"end":900}}"#
        let kid = try JSONDecoder().decode(Kid.self, from: Data(json.utf8))
        XCTAssertEqual(kid.school, F.kidA.school)
        XCTAssertNil(kid.pendingHours)
        let waiting = F.kidA.savingSchool(later, from: day(18), today: F.tuesday)
        XCTAssertEqual(try JSONDecoder().decode(Kid.self, from: JSONEncoder().encode(waiting)), waiting)
    }

    // MARK: Reading templates by date (spec #255)

    private func block(_ title: String, _ kind: SlotKind, _ start: Int, _ end: Int, medal: Bool = true) -> RoutineBlock {
        RoutineBlock(title: title, iconName: "actPlay", kind: kind, start: start, end: end,
                     trip: kind == .school ? Trip(way: .walk, leaveBefore: 10, medal: medal) : nil)
    }

    /// Kid A's weekday from 1 Nov: School 8:00 am – 3:00 pm between Breakfast and Play.
    private func weekday(from: Day, dinner: Int = 1080) -> Routine {
        Routine(kid: F.kidA.id, dayType: .weekday, from: from, blocks: [
            block("Sleep", .sleep, 0, 420), block("Breakfast", .morning, 420, 480), block("School", .school, 480, 900),
            block("Play", .play, 900, dinner), block("Dinner", .dinner, dinner, 1140), block("Sleep", .sleep, 1140, 1440),
        ])
    }

    private func school(_ kid: Kid, _ routines: [Routine], on date: Day) -> RoutineBlock? {
        DayPlanner.template(for: kid.id, on: date, routines: kid.readingWaitingHours(routines), holidays: [],
                            calendar: F.calendar)?.blocks.first { $0.kind == .school }
    }

    /// Before its day School reads today's record; from it, the waiting hours, in the version in use
    /// and in a later version that stores today's slot (S1, S2 of the design note). Nothing is stored.
    func testTemplatesReadTheWaitingHoursFromTheirDay() {
        let kid = F.kidA.savingSchool(later, from: day(18), today: F.tuesday)
        let later25 = weekday(from: day(25), dinner: 1110)
        let routines = [weekday(from: F.templatesFrom), later25]
        XCTAssertEqual(school(kid, routines, on: day(17))?.start, 480)
        XCTAssertEqual(school(kid, routines, on: day(18))?.start, 510)
        XCTAssertEqual(school(kid, routines, on: day(18))?.end, 840)
        let on25 = DayPlanner.template(for: kid.id, on: day(25), routines: kid.readingWaitingHours(routines),
                                       holidays: [], calendar: F.calendar)
        XCTAssertEqual(on25?.blocks.first { $0.kind == .school }?.start, 510, "a later version reads it too")
        XCTAssertEqual(on25?.blocks.first { $0.kind == .dinner }?.start, 1110, "its own edit stays")
        XCTAssertEqual(on25?.blocks.first { $0.kind == .play }?.start, 840, "Play follows School's end")
        // Cancelled: nothing was stored, so every day reads today's hours again (S1).
        var cancelled = kid
        cancelled.pendingHours = nil
        XCTAssertEqual(school(cancelled, routines, on: day(25))?.start, 480)
        XCTAssertEqual(cancelled.readingWaitingHours(routines), routines)
    }

    /// Spec #255 point 4 (S4): a version on the waiting day with another edit keeps it, waiting or not.
    func testTheWaitingDaysOwnVersionKeepsItsOtherEdits() {
        let kid = F.kidA.savingSchool(later, from: day(18), today: F.tuesday)
        let routines = [weekday(from: F.templatesFrom), weekday(from: day(18), dinner: 1110)]
        let read = kid.readingWaitingHours(routines)
        XCTAssertEqual(read.count, 2, "no copy when a version starts on the day")
        let on18 = DayPlanner.template(for: kid.id, on: day(18), routines: read, holidays: [], calendar: F.calendar)
        XCTAssertEqual(on18?.blocks.first { $0.kind == .school }?.start, 510)
        XCTAssertEqual(on18?.blocks.first { $0.kind == .dinner }?.start, 1110)
    }

    /// The waiting medal shows from its day; a newer version without School is never shadowed.
    func testTheWaitingMedalAndANewerVersionWithoutSchool() {
        let kid = F.kidA.savingSchool(later, from: day(18), today: F.tuesday, medal: false)
        XCTAssertEqual(school(kid, [weekday(from: F.templatesFrom)], on: day(18))?.trip?.medal, false)
        XCTAssertEqual(school(kid, [weekday(from: F.templatesFrom)], on: day(17))?.trip?.medal, true)
        let free = Routine(kid: kid.id, dayType: .weekday, from: day(16), blocks: [block("Play", .play, 0, 1440)])
        let read = kid.readingWaitingHours([weekday(from: F.templatesFrom), free])
        XCTAssertEqual(read.count, 2, "the version in use on the day has no School: nothing to read")
    }

    /// A school move starting before the waiting day cuts it off; one after it keeps it until the move.
    func testASchoolMoveBoundsTheWaitingHours() {
        var kid = F.kidA.savingSchool(later, from: day(18), today: F.tuesday)
        let next = School(name: "Example Secondary School", days: Weekday.schoolDays, start: 450, end: 870)
        let routines = [weekday(from: F.templatesFrom), weekday(from: day(25))]
        kid.pendingSchool = PendingSchool(school: next, from: day(25))
        XCTAssertEqual(school(kid, routines, on: day(24))?.start, 510)
        XCTAssertEqual(school(kid, routines, on: day(25))?.start, 480, "the next place's version is its own")
        kid.pendingSchool = PendingSchool(school: next, from: day(18))
        XCTAssertEqual(kid.readingWaitingHours(routines), routines)
    }

    /// A series version saved from the waiting day on stores today's School slot and medal (S1).
    func testAVersionSavedWhileAChangeWaitsStoresTodaysSchool() {
        let kid = F.kidA.savingSchool(later, from: day(18), today: F.tuesday, medal: false)
        let stored = weekday(from: F.templatesFrom).blocks
        let shown = kid.readingWaitingHours([weekday(from: F.templatesFrom)]).last!.blocks
        XCTAssertEqual(shown.first { $0.kind == .school }?.start, 510)
        let kept = kid.storingSchool(shown, on: day(20), stored: stored)
        XCTAssertEqual(kept.first { $0.kind == .school }?.start, 480)
        XCTAssertEqual(kept.first { $0.kind == .school }?.end, 900)
        XCTAssertEqual(kept.first { $0.kind == .school }?.trip?.medal, true)
        XCTAssertEqual(kid.storingSchool(shown, on: day(17), stored: stored), shown, "before its day: as edited")
    }

    /// On its day Home writes the waiting hours into that day's and later versions, then the record
    /// (S2); a day before keeps today's hours (S3).
    func testOnItsDayTheWaitingHoursAreWrittenAndEarlierDaysKeepTheirs() {
        let kid = F.kidA.savingSchool(later, from: day(18), today: F.tuesday)
        let stored = [weekday(from: F.templatesFrom), weekday(from: day(25), dinner: 1110)]
        let written = kid.readingWaitingHours(stored)
        let after = kid.applyingWaitingChanges(on: day(18))
        XCTAssertNil(after.pendingHours)
        XCTAssertEqual(school(after, written, on: day(18))?.start, 510)
        XCTAssertEqual(school(after, written, on: day(25))?.start, 510)
        XCTAssertEqual(school(after, written, on: day(17))?.start, 480)
    }

    // MARK: A day's own template and a save from today (design answers to #255)

    private func own(_ date: Day, school: (Int, Int) = (480, 900), dinner: Int = 1080) -> Routine {
        var routine = weekday(from: date, dinner: dinner)
        routine.from = date
        routine.onlyOn = date
        if let index = routine.blocks.firstIndex(where: { $0.kind == .school }) {
            routine.blocks[index - 1].end = school.0
            routine.blocks[index].start = school.0
            routine.blocks[index].end = school.1
            routine.blocks[index + 1].start = school.1
        }
        return routine
    }

    /// A day's own template on D or later (a This day edit, a skip) reads School by date too; one
    /// whose School was set for that day (a late start) keeps it. A cancel returns both as they were.
    func testADaysOwnTemplateReadsSchoolByDate() {
        let kid = F.kidA.savingSchool(later, from: day(18), today: F.tuesday)
        let edited = own(day(20), dinner: 1110), lateStart = own(day(23), school: (600, 900))
        let routines = [weekday(from: F.templatesFrom), edited, lateStart, own(day(17))]
        XCTAssertEqual(school(kid, routines, on: day(20))?.start, 510, "follows the record: reads the waiting hours")
        XCTAssertEqual(DayPlanner.template(for: kid.id, on: day(20), routines: kid.readingWaitingHours(routines),
                                           holidays: [], calendar: F.calendar)?.blocks.first { $0.kind == .dinner }?.start,
                       1110)
        XCTAssertEqual(school(kid, routines, on: day(23))?.start, 600, "its own late start stays")
        XCTAssertEqual(school(kid, routines, on: day(17))?.start, 480, "before D")
    }

    /// A day's own template saved on D or later stores today's School, never the waiting copy.
    func testADaysOwnTemplateSavedWhileAChangeWaitsStoresTodaysSchool() {
        let kid = F.kidA.savingSchool(later, from: day(18), today: F.tuesday, medal: false)
        let shown = kid.readingWaitingHours([own(day(20))]).first!.blocks
        XCTAssertEqual(shown.first { $0.kind == .school }?.start, 510)
        let kept = kid.storingSchool(shown, on: day(20), stored: weekday(from: F.templatesFrom).blocks)
        XCTAssertEqual(kept.first { $0.kind == .school }?.start, 480)
        XCTAssertEqual(kept.first { $0.kind == .school }?.trip?.medal, true)
        let late = own(day(20), school: (600, 900)).blocks
        XCTAssertEqual(kid.storingSchool(late, on: day(20), stored: late), late, "a late start of its own stays")
    }

    /// On its day Home writes the waiting hours into the days' own templates that follow the record too.
    func testOnItsDayTheOwnTemplatesAreWrittenToo() {
        let kid = F.kidA.savingSchool(later, from: day(18), today: F.tuesday)
        let written = kid.readingWaitingHours([weekday(from: F.templatesFrom), own(day(20))])
        XCTAssertEqual(written.first { $0.onlyOn == day(20) }?.blocks.first { $0.kind == .school }?.start, 510)
    }

    /// A School save from today reaches later templates, a day's own ones included, that follow the
    /// old record; one with its own School times and earlier versions stay.
    func testASaveFromTodayReachesLaterTemplates() {
        let old = F.kidA.school!
        let kid = F.kidA.savingSchool(later, from: F.tuesday, today: F.tuesday)
        let routines = [weekday(from: F.templatesFrom), weekday(from: day(25), dinner: 1110), own(day(20)),
                        own(day(23), school: (600, 900)), own(F.monday)]
        let moved = kid.followingSchool(routines, from: F.tuesday, old: old, medal: false)
        XCTAssertEqual(moved.map { $0.onlyOn ?? $0.from }, [day(25), day(20)])
        XCTAssertEqual(moved.first?.blocks.first { $0.kind == .school }?.start, 510)
        XCTAssertEqual(moved.first?.blocks.first { $0.kind == .school }?.trip?.medal, false)
        XCTAssertEqual(moved.first?.blocks.first { $0.kind == .dinner }?.start, 1110, "its own edit stays")
    }
}
