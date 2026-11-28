import Domain
import Foundation
import XCTest

/// Spec G1 "One card for everything on the clock": items sit on top of the day template on the G1
/// clock, their edges are knobs, and skips, removes and adds wait for Save under one Undo.
final class ClockItemsTests: XCTestCase {
    private typealias F = Fixture
    /// Kid A's seed school day: … Snack 900–960, Free time 960–1020, Play 1020–1110, Dinner 1110–1155 …
    private var blocks: [RoutineBlock] {
        SeedData.routines.first { $0.kid == SeedData.kidA.id && $0.dayType == .weekday }!.blocks
    }
    private let swimID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
    private let newID = UUID(uuidString: "00000000-0000-0000-0000-0000000000A2")!

    /// Swimming every week, 16:00–17:00 on top of Free time and Play.
    private var swim: ClockItem {
        ClockItem(id: swimID, title: "Swimming", iconName: "actSwim", start: 960, end: 1020 + 30, isRepeating: true)
    }

    private func edit(_ items: [ClockItem]) -> TemplateEdit { TemplateEdit(blocks: blocks, items: items) }

    /// An every-week item for Kid A of the seed family.
    private func series(_ title: String = "Swimming", id: UUID = UUID(), days: Set<Weekday>, start: Int = 960,
                        end: Int = 1050, after: EventRef? = nil, gap: Int = 0) -> ScheduleItem {
        ScheduleItem(id: id, title: title, iconName: "actSwim", audience: .kid(SeedData.kidA.id), start: start, end: end,
                     recurrence: .weekly(days, from: F.templatesFrom, until: nil), skippedDays: [],
                     skipsHolidays: false, showsStar: false, after: after, afterGap: gap)
    }

    func testItemsCutTheTemplateTheyLieOn() {
        let edit = edit([swim])
        let pieces = edit.slices.filter { $0.start >= 900 && $0.end <= 1155 }.map { [$0.title, "\($0.start)", "\($0.end)"] }
        XCTAssertEqual(pieces, [["Snack", "900", "960"], ["Swimming", "960", "1050"], ["Play", "1050", "1110"],
                                ["Dinner", "1110", "1155"]])
        XCTAssertEqual(edit.blocks, TemplateEdit(blocks: blocks).blocks, "the template underneath stays")
    }

    /// The "+" shows on every knob between two slices that are not free time, an item's edges too
    /// (user, 2026-11-21).
    func testItemEdgesAreKnobsWithPlus() {
        let knobs = edit([swim]).clockKnobs
        let at = { (minute: Int) in knobs.first { $0.minute == minute } }
        XCTAssertEqual(at(960)?.edge, .itemStart(swimID))
        XCTAssertEqual(at(1050)?.edge, .itemEnd(swimID))
        XCTAssertEqual(at(960)?.showsAdd, true, "Snack | Swimming")
        XCTAssertEqual(at(1050)?.showsAdd, true, "Swimming | Play")
        XCTAssertEqual(at(1155)?.showsAdd, true, "Dinner | Shower")
        XCTAssertEqual(at(900)?.showsAdd, true, "School | Snack")
        XCTAssertNil(at(1020), "Free | Play is under Swimming")
        let plain = TemplateEdit(blocks: blocks).clockKnobs
        XCTAssertEqual(plain.filter(\.showsAdd).map(\.minute), [390, 450, 900, 1110, 1155, 1200],
                       "no + beside free time")
    }

    func testDraggingAnItemEdgeMovesOnlyTheItem() {
        var edit = edit([swim])
        let range = edit.range(of: .itemEnd(swimID))
        XCTAssertEqual(range, 975...1110, "15 minutes long at least; not past Play's end")
        edit.beginChange()
        XCTAssertEqual(edit.move(.itemEnd(swimID), to: 1072, within: range), .moved(1070))
        XCTAssertEqual(edit.item(swimID)?.end, 1070)
        XCTAssertEqual(edit.blocks.first { $0.title == "Play" }?.start, 1020, "Play itself stays")
        XCTAssertEqual(edit.move(.itemEnd(swimID), to: 1200, within: range), .stopped(1110))
    }

    /// No forced gaps: a template piece under 15 minutes beside a moved item edge goes under the item.
    func testAShortPieceBesideAnItemGoesUnderIt() {
        var edit = edit([swim])
        edit.beginChange()
        _ = edit.move(.itemEnd(swimID), to: 1100, within: edit.range(of: .itemEnd(swimID)))
        edit.settleItem(swimID)
        XCTAssertEqual(edit.item(swimID)?.end, 1110)
        XCTAssertTrue(edit.clockKnobs.contains { $0.minute == 1110 && $0.edge == .itemEnd(swimID) })
    }

    /// A template knob stops 15 minutes short of an item over the slice beside it.
    func testATemplateKnobNeverGoesUnderAnItem() {
        let edit = edit([swim])
        // Snack 900–960 | Swimming from 960: School's end can go no later than Snack's visible end - 15.
        XCTAssertEqual(edit.range(of: .blocks(before: edit.blocks.firstIndex { $0.kind == .school }!)).upperBound, 945)
    }

    /// One Undo covers a skip, a remove and an add, back to the last save.
    func testOneUndoForSkipRemoveAndAdd() {
        var edit = edit([swim])
        edit.setItemSkipped(swimID, true)
        XCTAssertEqual(edit.slices.first { $0.source == .item(swimID) }?.isSkipped, true, "faded, still on the clock")
        edit.removeItem(swimID)
        XCTAssertNil(edit.slices.first { $0.source == .item(swimID) })
        XCTAssertTrue(edit.hasSeriesChange)
        edit.add(ClockItem(id: newID, title: "Piano", iconName: "actPiano", start: 1155, end: 1185, isRepeating: false,
                           isNew: true))
        XCTAssertEqual(edit.firstItemChange?.title, "Swimming")
        edit.undo()
        XCTAssertNil(edit.item(newID))
        edit.undo()
        XCTAssertEqual(edit.item(swimID)?.isRemoved, false)
        edit.undo()
        XCTAssertEqual(edit.item(swimID)?.isSkipped, false)
        XCTAssertFalse(edit.isChanged)
        edit.redo()
        XCTAssertEqual(edit.item(swimID)?.isSkipped, true)
    }

    /// A new item that was never saved goes at once on Remove; Undo brings it back.
    func testRemovingANewItem() {
        var edit = edit([])
        edit.add(ClockItem(id: newID, title: "Piano", iconName: "actPiano", start: 1155, end: 1185, isRepeating: false,
                           isNew: true))
        edit.removeItem(newID)
        XCTAssertNil(edit.item(newID))
        edit.undo()
        XCTAssertNotNil(edit.item(newID))
    }

    /// Each template change keeps its scope: the Every time ones replay onto the day type's template
    /// (never a skip), the This day ones onto the day's own.
    func testTemplateChangesReplayByScope() {
        var clock = edit([])
        let play = clock.blocks.firstIndex { $0.title == "Play" }!
        clock.setSkipped(play, true)
        _ = clock.setEnd(ofBlock: clock.blocks.firstIndex { $0.title == "Dinner" }!, to: 1170, scope: .allDays)
        clock.makeFree(clock.blocks.firstIndex { $0.title == "Shower" }!, scope: .allDays)
        XCTAssertTrue(clock.hasAllDaysChange)
        XCTAssertTrue(clock.hasThisDayTemplateChange)
        let series = clock.seriesBlocks(from: blocks)
        XCTAssertEqual(series.first { $0.title == "Dinner" }?.end, 1170)
        XCTAssertFalse(series.contains { $0.title == "Shower" })
        XCTAssertFalse(series.contains(where: \.isSkipped), "a skip is never every day")
        let day = clock.replaying(on: clock.savedBlocks, scopes: [.thisDay])
        XCTAssertEqual(day.first { $0.title == "Play" }?.isSkipped, true)
        XCTAssertEqual(day.first { $0.title == "Dinner" }?.end, 1155, "the Every time changes are not in it")
        clock.undo()
        clock.undo()
        XCTAssertFalse(clock.hasAllDaysChange, "Undo takes the scoped changes back too")
    }

    // MARK: Items of the day

    func testClockItemsKeepASkippedItemAndPlaceAfterSchool() {
        var swimming = series(id: swimID, days: [.tuesday])
        swimming.skippedDays = [F.tuesday]
        let reading = series("Reading", days: [.tuesday], after: .school, gap: 30)
        let items = DayPlanner.clockItems(on: F.tuesday, kid: SeedData.kidA.id, routines: SeedData.routines,
                                          items: [swimming, reading], holidays: [], calendar: F.calendar)
        XCTAssertEqual(items.first { $0.id == swimID }?.isSkipped, true)
        let after = items.first { $0.title == "Reading" }
        XCTAssertEqual(after?.start, 900 + 30, "30 minutes after School ends")
        XCTAssertEqual(after?.isAnchored, true)
        var anchored = TemplateEdit(blocks: blocks, items: items)
        XCTAssertFalse(anchored.clockKnobs.contains { $0.edge == .itemStart(after!.id) }, "its edges follow School")
        XCTAssertEqual(anchored.setItemStart(after!.id, to: 960), .noKnob)
    }

    // MARK: Save

    private func writes(_ items: [ClockItem], saved: [ClockItem], originals: [ScheduleItem],
                        from: Day? = nil) -> ClockSave.Writes {
        var ids = [UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!]
        return ClockSave.writes(items: items, saved: saved, originals: originals, kid: SeedData.kidA.id, day: F.tuesday,
                                from: from ?? F.tuesday, calendar: F.calendar,
                                newID: { ids.removeFirst() })
    }

    func testSaveSkipsThisDayAndEndsASeriesFromTheDay() {
        let original = series(id: swimID, days: [.tuesday])
        var skipped = swim
        skipped.isSkipped = true
        XCTAssertEqual(writes([skipped], saved: [swim], originals: [original]).saved.first?.skippedDays, [F.tuesday])
        var removed = swim
        removed.isRemoved = true
        let ended = writes([removed], saved: [swim], originals: [original], from: F.thursday)
        XCTAssertEqual(ended.saved.first?.recurrence.range?.until, F.wednesday, "earlier days stay")
        XCTAssertEqual(writes([removed], saved: [swim], originals: [original], from: original.recurrence.range!.from).deleted,
                       [swimID], "a series that has not started yet goes")
        XCTAssertTrue(writes([swim], saved: [swim], originals: [original]).isEmpty, "nothing changed")
    }

    func testSaveRemovesAJustOnceItem() {
        let party = ScheduleItem(id: swimID, title: "Party", iconName: "cake", audience: .kid(SeedData.kidA.id),
                                 start: 960, end: 1020, recurrence: .once(F.tuesday), skippedDays: [],
                                 skipsHolidays: false, showsStar: true)
        var removed = ClockItem(id: swimID, title: "Party", iconName: "cake", start: 960, end: 1020, isRepeating: false)
        let was = removed
        removed.isRemoved = true
        XCTAssertEqual(writes([removed], saved: [was], originals: [party]).deleted, [swimID])
    }

    /// Spec "Tapping +": a clock add is a just-once item on This day, an every-week item on the day's
    /// weekday on Every time, never a template change.
    func testSaveAddsAJustOnceOrAnEveryWeekItem() {
        let once = ClockItem(id: newID, title: "Piano", iconName: "actPiano", start: 1155, end: 1185, isRepeating: false,
                             isNew: true)
        let added = writes([once], saved: [], originals: []).saved.first
        XCTAssertEqual(added?.recurrence, .once(F.tuesday))
        XCTAssertEqual(added?.audience, .kid(SeedData.kidA.id))
        XCTAssertEqual([added?.start, added?.end], [1155, 1185])
        var weekly = once
        weekly.isRepeating = true
        XCTAssertEqual(writes([weekly], saved: [], originals: [], from: F.thursday).saved.first?.recurrence,
                       .weekly([.tuesday], from: F.thursday, until: nil))
    }

    /// New times by the scope they were changed in: This day keeps them for the day; Every time
    /// splits the series from the date.
    func testSaveMovesTimesThisDayOrFromADate() {
        let original = series(id: swimID, days: [.tuesday])
        var moved = swim
        moved.end = 1080
        moved.retimeScope = .thisDay
        let thisDay = writes([moved], saved: [swim], originals: [original]).saved
        XCTAssertEqual(thisDay.first?.dayChanges, [DayChange(day: F.tuesday, end: 1080)])
        moved.retimeScope = .allDays
        let allDays = writes([moved], saved: [swim], originals: [original], from: F.thursday).saved
        XCTAssertEqual(allDays.count, 2, "the old part ends, a new part starts on Thursday")
        XCTAssertEqual(allDays.last?.end, 1080)
    }
}
