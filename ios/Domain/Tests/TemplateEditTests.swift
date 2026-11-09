import Domain
import XCTest

/// Spec C6 drag rules: knobs on the rim move the shared edge, snap to 5 minutes, keep every slice
/// at 15 minutes or more, never cross, and the school block's edges stay put.
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
        XCTAssertEqual(edit.knobs.filter(\.isLocked).map(\.minute), [450, 900])
    }

    func testDraggingMovesTheSharedEdgeAndSnapsToFiveMinutes() {
        var edit = edit
        edit.beginChange()
        XCTAssertEqual(edit.moveKnob(knob(edit, at: 1155), to: 1168), .moved(1170))
        XCTAssertEqual(edit.blocks.first { $0.title == "Dinner" }?.end, 1170)
        XCTAssertEqual(edit.blocks.first { $0.title == "Shower" }?.start, 1170)
        XCTAssertEqual(edit.effect(ofKnob: knob(edit, at: 1170)), "Shower now starts at 7:30 pm and is 30 min.")
    }

    func testASliceNeverGoesBelowFifteenMinutesOrCrossesAKnob() {
        var edit = edit
        edit.beginChange()
        // Shower 1155–1200: its start can go no later than 1185.
        XCTAssertEqual(edit.moveKnob(knob(edit, at: 1155), to: 1230), .stopped(1185))
        // Dinner's start can go no earlier than Play's start + 15 (1035).
        XCTAssertEqual(edit.moveKnob(knob(edit, at: 1110), to: 1000), .stopped(1035))
    }

    func testSchoolEdgesAreLocked() {
        var edit = edit
        XCTAssertEqual(edit.moveKnob(knob(edit, at: 450), to: 480), .locked)
        XCTAssertEqual(edit.blocks.first { $0.kind == .school }?.start, 450)
    }

    func testTypedTimesUseTheSameRules() {
        var edit = edit
        let dinner = edit.blocks.firstIndex { $0.title == "Dinner" }!
        XCTAssertEqual(edit.setEnd(ofBlock: dinner, to: 1172), .moved(1170))
        XCTAssertEqual(edit.setStart(ofBlock: dinner, to: 1100), .moved(1100))
        XCTAssertEqual(edit.blocks.first { $0.title == "Play" }?.end, 1100)
        XCTAssertEqual(edit.setStart(ofBlock: edit.blocks.firstIndex { $0.kind == .school }!, to: 420), .locked)
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
