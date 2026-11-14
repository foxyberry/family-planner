import Domain
import XCTest

/// Spec C6 drag rules: knobs on the rim move the shared edge, snap to 5 minutes, keep every slice
/// at 15 minutes or more and never cross. School's edges move too (layout v37); free time under 15
/// minutes never stays; a tap on a knob can add a slice between (G1e).
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

    /// Board G1e: "+" on a shared knob puts 30 minutes of free time there for the new-slice card,
    /// from the slice after it, or before it when the one after is under 45 minutes.
    func testAddBetweenTakesThirtyMinutes() {
        var edit = edit
        // Dinner 1110–1155 | Shower 1155–1200: Shower has 45 minutes, so the slice comes out of it.
        let fromAfter = edit.insertBetween(knob: knob(edit, at: 1155))!
        XCTAssertEqual(edit.blocks[fromAfter].start, 1155)
        XCTAssertEqual(edit.blocks[fromAfter + 1].start, 1185)
        edit.dropLastChange()
        // Shower 1170–1200 is under 45: the slice comes out of Dinner and ends at the knob.
        edit.beginChange()
        _ = edit.moveKnob(knob(edit, at: 1155), to: 1170)
        let slot = edit.insertBetween(knob: knob(edit, at: 1170))!
        XCTAssertEqual(edit.blocks[slot].kind, .free)
        XCTAssertEqual(edit.blocks[slot].start, 1140)
        XCTAssertEqual(edit.blocks[slot].end, 1170)
        XCTAssertEqual(edit.blocks[slot - 1].end, 1140)
        // Breakfast 390–450 | School 450–900: from School.
        let school = edit.insertBetween(knob: knob(edit, at: 450))!
        XCTAssertEqual(edit.blocks[school].start, 450)
        XCTAssertEqual(edit.blocks[school + 1].start, 480)
        edit.fill(school, title: "Reading", iconName: "actStory", kind: .play)
        XCTAssertEqual(edit.blocks[school].end, 480, "the new slice keeps its 30 minutes")
        edit.undo()
        edit.undo()
        edit.undo()
        edit.undo()
        XCTAssertFalse(edit.isChanged)
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

    func testMakeFreeThenFillAndUndoBackToTheStart() {
        let start = edit
        var edit = edit
        let play = edit.blocks.firstIndex { $0.title == "Play" }!
        let playStart = edit.blocks[play].start
        let free = edit.makeFree(play)
        XCTAssertEqual(edit.blocks[free].kind, .free)
        XCTAssertEqual(edit.blocks[free].iconName, "")
        let freeStart = edit.blocks[free].start
        edit.fill(free, title: "Piano", iconName: "actPiano", kind: .play)
        XCTAssertEqual(edit.blocks[free].title, "Piano")
        XCTAssertEqual(edit.blocks[free].start, freeStart)
        XCTAssertLessThanOrEqual(freeStart, playStart)
        XCTAssertTrue(edit.isChanged)
        edit.undo()
        XCTAssertEqual(edit.blocks[free].kind, .free)
        edit.undo()
        XCTAssertEqual(edit.blocks, start.blocks)
        XCTAssertFalse(edit.isChanged)
    }

    func testTheSchoolBlockCannotBeMadeFree() {
        var edit = edit
        edit.makeFree(edit.blocks.firstIndex { $0.kind == .school }!)
        XCTAssertFalse(edit.isChanged)
    }

    /// User, 2026-11-09: slices come and go. A new one takes the first hour of free time and leaves
    /// the rest free; freeing a slice joins it with the free time beside it.
    func testSlicesGrowAndShrink() {
        var edit = edit
        let count = edit.blocks.count
        let play = edit.blocks.firstIndex { $0.title == "Play" }!
        let slot = edit.makeFree(play)
        let freed = edit.blocks.count
        XCTAssertLessThanOrEqual(freed, count)
        let span = (edit.blocks[slot].start, edit.blocks[slot].end)
        edit.fill(slot, title: "Piano", iconName: "actPiano", kind: .afterSchool, length: 30)
        XCTAssertEqual(edit.blocks.count, freed + 1)
        XCTAssertEqual(edit.blocks[slot].end, span.0 + 30)
        XCTAssertEqual(edit.blocks[slot + 1].kind, .free)
        XCTAssertEqual(edit.blocks[slot + 1].end, span.1)
        // Freeing Piano joins it with the free time after it: one free slice again.
        let free = edit.makeFree(slot)
        XCTAssertEqual(edit.blocks.count, freed)
        XCTAssertEqual(edit.blocks[free].start, span.0)
        XCTAssertEqual(edit.blocks[free].end, span.1)
    }

    /// Free time shorter than 15 minutes after the new slice goes to the new slice.
    func testFillTakesAShortRemainder() {
        var edit = edit
        let slot = edit.makeFree(edit.blocks.firstIndex { $0.title == "Play" }!)
        let end = edit.blocks[slot].end
        edit.fill(slot, title: "Piano", iconName: "actPiano", kind: .play, length: end - edit.blocks[slot].start - 10)
        XCTAssertEqual(edit.blocks[slot].end, end)
    }
}
