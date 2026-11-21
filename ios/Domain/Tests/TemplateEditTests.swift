import Domain
import XCTest

/// Spec C6 drag rules: knobs on the rim move the shared edge, snap to 5 minutes, keep every slice
/// at 15 minutes or more and never cross. School's edges move too (layout v37); free time under 15
/// minutes never stays; a "+" on a shared knob covers 30 minutes (G1).
final class TemplateEditTests: XCTestCase {
    /// Kid A's seed school day: Sleep 0–390, Breakfast 390–450, School 450–900 (locked), Snack 900–960,
    /// Free time 960–1020, Play 1020–1110, Dinner 1110–1155, Shower 1155–1200, Sleep 1200–1440.
    private var edit: TemplateEdit {
        TemplateEdit(blocks: SeedData.routines.first { $0.kid == SeedData.kidA.id && $0.dayType == .weekday }!.blocks)
    }

    private func knob(_ edit: TemplateEdit, at minute: Int) -> Int {
        edit.knobs.firstIndex { $0.minute == minute }!
    }

    func testKnobsSitBetweenSlicesButNotAtMidnight() {
        let minutes = edit.knobs.map(\.minute)
        XCTAssertEqual(minutes, [390, 450, 900, 960, 1020, 1110, 1155, 1200])
    }

    func testDraggingMovesTheSharedEdgeAndSnapsToFiveMinutes() {
        var edit = edit
        edit.beginChange()
        XCTAssertEqual(edit.moveKnob(knob(edit, at: 1155), to: 1168), .moved(1170))
        XCTAssertEqual(edit.blocks.first { $0.title == "Dinner" }?.end, 1170)
        XCTAssertEqual(edit.blocks.first { $0.title == "Shower" }?.start, 1170)
    }

    /// Board G1d names the first changed slice; nothing is named before a change or after a save.
    func testFirstChangeIsTheFirstMovedSlice() {
        var edit = edit
        XCTAssertNil(edit.firstChange, "nothing moved yet")
        edit.beginChange()
        _ = edit.moveKnob(knob(edit, at: 1155), to: 1170)
        XCTAssertEqual(edit.firstChange?.title, "Dinner")
        edit.markSaved()
        XCTAssertFalse(edit.isChanged)
    }

    func testASliceNeverGoesBelowFifteenMinutesOrCrossesAKnob() {
        var edit = edit
        edit.beginChange()
        // Shower 1155–1200: its start can go no later than 1185.
        XCTAssertEqual(edit.moveKnob(knob(edit, at: 1155), to: 1230), .stopped(1185))
        // Dinner's start can go no earlier than Play's start + 15 (1035).
        XCTAssertEqual(edit.moveKnob(knob(edit, at: 1110), to: 1000), .stopped(1035))
    }

    func testSchoolEdgesMoveLikeAnyOther() {
        var edit = edit
        edit.beginChange()
        XCTAssertEqual(edit.moveKnob(knob(edit, at: 450), to: 480), .moved(480))
        XCTAssertEqual(edit.blocks.first { $0.kind == .school }?.start, 480)
        XCTAssertEqual(edit.moveKnob(knob(edit, at: 900), to: 870), .moved(870))
        XCTAssertEqual(edit.blocks.first { $0.kind == .school }?.end, 870)
    }

    /// User, 2026-11-14: no forced gaps. A drag that leaves free time under 15 minutes snaps the
    /// moved edge onto the next slice, and the two share one knob.
    func testShortFreeTimeJoinsTheMovedSlice() {
        var edit = edit
        edit.beginChange()
        // Snack 900–960, Free 960–1020, Play 1020–1110: Snack's end goes to 1010.
        XCTAssertEqual(edit.moveKnob(knob(edit, at: 960), to: 1010), .moved(1010))
        let snack = edit.blocks.firstIndex { $0.title == "Snack" }!
        edit.closeShortGaps(favoring: snack)
        XCTAssertEqual(edit.blocks[snack].end, 1020)
        XCTAssertEqual(edit.blocks[snack + 1].title, "Play")
        XCTAssertFalse(edit.blocks.contains { $0.kind == .free })
        XCTAssertTrue(edit.knobs.contains { $0.minute == 1020 })
    }

    func testABareGapUnderFifteenMinutesCloses() {
        var blocks = edit.blocks
        let dinner = blocks.firstIndex { $0.title == "Dinner" }!
        blocks[dinner].end -= 5 // a 5-minute hole before Shower
        let closed = TemplateEdit(blocks: blocks)
        XCTAssertEqual(closed.blocks.first { $0.title == "Dinner" }?.end, closed.blocks.first { $0.title == "Shower" }?.start)
    }

    /// Spec "Add between two slices": the "+" on a shared knob covers 30 minutes of the slice after
    /// it, or of the slice before it when the one after is under 45 minutes. The template stays.
    func testAddBetweenCoversThirtyMinutes() {
        var edit = edit
        let at = { (minute: Int) in edit.clockKnobs.firstIndex { $0.minute == minute }! }
        // Dinner 1110–1155 | Shower 1155–1200: Shower has 45 minutes.
        XCTAssertEqual(edit.addSpan(atKnob: at(1155)), 1155..<1185)
        // Shower 1170–1200 is under 45: the item comes out of Dinner and ends at the knob.
        edit.beginChange()
        _ = edit.moveKnob(knob(edit, at: 1155), to: 1170)
        XCTAssertEqual(edit.addSpan(atKnob: at(1170)), 1140..<1170)
        // Breakfast 390–450 | School 450–900: from School.
        XCTAssertEqual(edit.addSpan(atKnob: at(450)), 450..<480)
        XCTAssertEqual(edit.blocks.count, self.edit.blocks.count, "a span changes nothing")
    }

    func testSchoolHoursFollowTheMovedSlice() {
        let school = School(name: "Example Primary School", days: Weekday.schoolDays, start: 465, end: 810,
                            arriveBy: 450, latest: 460)
        let moved = school.moved(sliceStart: 480, sliceEnd: 840)
        XCTAssertEqual(moved.arriveBy, 480)
        XCTAssertEqual(moved.start, 495)
        XCTAssertEqual(moved.latest, 490, "Latest keeps its 10-minute grace")
        XCTAssertEqual(moved.end, 840)
        let plain = School(name: "Example Primary School", days: Weekday.schoolDays, start: 450, end: 810)
        XCTAssertEqual(plain.moved(sliceStart: 420, sliceEnd: 810).start, 420)
    }

    func testTypedTimesUseTheSameRules() {
        var edit = edit
        let dinner = edit.blocks.firstIndex { $0.title == "Dinner" }!
        XCTAssertEqual(edit.setEnd(ofBlock: dinner, to: 1172), .moved(1170))
        XCTAssertEqual(edit.setStart(ofBlock: dinner, to: 1100), .moved(1100))
        XCTAssertEqual(edit.blocks.first { $0.title == "Play" }?.end, 1100)
        XCTAssertEqual(edit.setStart(ofBlock: edit.blocks.firstIndex { $0.kind == .school }!, to: 420), .moved(420))
        XCTAssertEqual(edit.setStart(ofBlock: 0, to: 30), .noKnob, "the day's first start has no knob")
    }

    func testMakeFreeAndUndoBackToTheStart() {
        let start = edit
        var edit = edit
        let play = edit.blocks.firstIndex { $0.title == "Play" }!
        let playStart = edit.blocks[play].start
        let free = edit.makeFree(play)
        XCTAssertEqual(edit.blocks[free].kind, .free)
        XCTAssertEqual(edit.blocks[free].iconName, "")
        XCTAssertLessThanOrEqual(edit.blocks[free].start, playStart, "joined with the free time before it")
        XCTAssertTrue(edit.isChanged)
        edit.undo()
        XCTAssertEqual(edit.blocks, start.blocks)
        XCTAssertFalse(edit.isChanged)
    }

    /// Spec C6 "One card": Remove on All days makes School free time too (after its ConfirmCard).
    func testTheSchoolBlockCanBeMadeFree() {
        var edit = edit
        edit.makeFree(edit.blocks.firstIndex { $0.kind == .school }!)
        XCTAssertFalse(edit.blocks.contains { $0.kind == .school })
        XCTAssertTrue(edit.isChanged)
    }

    /// Spec "Tapping +": the free-paper "+" covers the first hour; a span of an hour or less, or a
    /// leftover under 15 minutes, is covered whole.
    func testFreePaperPlusCoversTheFirstHour() {
        var edit = edit
        // Free time 960–1020 is one hour: all of it.
        XCTAssertEqual(edit.addSpan(inFreeAt: 980), 960..<1020)
        XCTAssertNil(edit.addSpan(inFreeAt: 1030), "Play is not free time")
        // Freeing Play joins it with the free time before it: 960–1110, so the first hour.
        let slot = edit.makeFree(edit.blocks.firstIndex { $0.title == "Play" }!)
        XCTAssertEqual(edit.blocks[slot].start, 960)
        XCTAssertEqual(edit.addSpan(inFreeAt: 1000), 960..<1020)
        // 960–1030: the 10 minutes left join the new slice.
        _ = edit.setEnd(ofBlock: slot, to: 1030)
        XCTAssertEqual(edit.addSpan(inFreeAt: 960), 960..<1030)
    }

    /// Spec "Where the kid goes changes": at home turns School into free time; a new place without a
    /// School slice cuts one into the day.
    func testPlacingSchoolForAtHomeAndANewPlace() {
        let blocks = [
            RoutineBlock(title: "Sleep", iconName: "actSleep", kind: .sleep, start: 0, end: 420),
            RoutineBlock(title: "Breakfast", iconName: "actBreakfast", kind: .morning, start: 420, end: 450),
            RoutineBlock(title: "School", iconName: "actSchool", kind: .school, start: 450, end: 810, isLocked: true),
            RoutineBlock(title: "Free", iconName: "", kind: .free, start: 810, end: 1080),
            RoutineBlock(title: "Dinner", iconName: "actDinner", kind: .dinner, start: 1080, end: 1440),
        ]
        let home = TemplateEdit.placingSchool(blocks, school: nil)
        XCTAssertFalse(home.contains { $0.kind == .school })
        XCTAssertEqual(home.filter { $0.kind == .free }.map { [$0.start, $0.end] }, [[450, 1080]])

        let preschool = School(name: "Example Preschool", days: Weekday.schoolDays, start: 510, end: 750, kind: .preschool)
        let placed = TemplateEdit.placingSchool(home, school: preschool)
        let slice = placed.first { $0.kind == .school }
        XCTAssertEqual(slice?.title, "Preschool")
        XCTAssertEqual(slice?.iconName, "playground")
        XCTAssertEqual([slice?.start, slice?.end], [510, 750])
        XCTAssertEqual(placed.map(\.start), placed.map(\.start).sorted())
        for (a, b) in zip(placed, placed.dropFirst()) { XCTAssertLessThanOrEqual(a.end, b.start) }

        let moved = TemplateEdit.placingSchool(blocks, school: preschool)
        XCTAssertEqual(moved.first { $0.kind == .school }?.title, "Preschool", "a school slice is renamed")
    }
}
