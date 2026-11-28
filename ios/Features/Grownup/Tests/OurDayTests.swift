import ComposableArchitecture
import Domain
import Foundation
import Grownup
import Localization
import ScheduleStore
import XCTest

/// G1 · Our day: dragging, limits, School's edges, the "+" adds, one slice card for day slices,
/// items and School, undo, leaving and saving.
@MainActor
final class OurDayTests: XCTestCase {
    private typealias F = Fixture
    private let tuesday = Day(year: 2026, month: 11, day: 10)

    /// What a save wrote to the store.
    private final class Writes: Sendable {
        let routines = LockIsolated<[Routine]>([])
        let items = LockIsolated<[ScheduleItem]>([])
        let deleted = LockIsolated<[ScheduleItem.ID]>([])
    }

    private func store(saved: LockIsolated<[Routine]> = .init([]), savedKids: LockIsolated<[Kid]> = .init([]),
                       items: [ScheduleItem] = [], writes: Writes = Writes(),
                       kids: [Kid] = SeedData.kids, routines: [Routine] = SeedData.routines)
        -> TestStoreOf<OurDayFeature> {
        let store = TestStore(initialState: OurDayFeature.State(kid: SeedData.kidA.id, today: tuesday,
                                                                calendar: F.calendar)) {
            OurDayFeature()
        } withDependencies: {
            $0.calendar = F.calendar
            $0.date.now = self.tuesday.date(minute: 600, calendar: F.calendar)
            $0.uuid = .incrementing
            $0.scheduleStore.load = { ScheduleSnapshot(kids: kids, routines: routines, items: items) }
            $0.scheduleStore.saveRoutine = { routine in
                saved.withValue { $0.append(routine) }
                writes.routines.withValue { $0.append(routine) }
            }
            $0.scheduleStore.saveAll = { new in writes.items.withValue { $0 += new } }
            $0.scheduleStore.delete = { id in writes.deleted.withValue { $0.append(id) } }
            $0.scheduleStore.saveKid = { kid in savedKids.withValue { $0.append(kid) } }
            $0.holidays.holidays = { _ in [] }
            $0.schoolDirectory.calendar = { _, _ in .none }
        }
        store.exhaustivity = .off
        return store
    }

    private func loaded(saved: LockIsolated<[Routine]> = .init([]), savedKids: LockIsolated<[Kid]> = .init([]),
                        items: [ScheduleItem] = [], writes: Writes = Writes(),
                        kids: [Kid] = SeedData.kids,
                        routines: [Routine] = SeedData.routines) async -> TestStoreOf<OurDayFeature> {
        let store = store(saved: saved, savedKids: savedKids, items: items, writes: writes, kids: kids, routines: routines)
        await store.send(.task)
        await store.receive(\.loaded)
        return store
    }

    private func knob(_ store: TestStoreOf<OurDayFeature>, at minute: Int) -> Int {
        store.state.edit.clockKnobs.firstIndex { $0.minute == minute }!
    }

    /// Spec "No empty slice card": a hold on Dinner opens G1 with Dinner picked, not the slice now.
    func testOpensOnTheHeldSlice() async {
        var state = OurDayFeature.State(kid: SeedData.kidA.id, today: tuesday, calendar: F.calendar)
        state.heldMinute = 1110
        let store = TestStore(initialState: state) { OurDayFeature() } withDependencies: {
            $0.calendar = F.calendar
            $0.date.now = self.tuesday.date(minute: 600, calendar: F.calendar)
            $0.scheduleStore.load = { ScheduleSnapshot(kids: SeedData.kids, routines: SeedData.routines, items: []) }
            $0.holidays.holidays = { _ in [] }
            $0.schoolDirectory.calendar = { _, _ in .none }
        }
        store.exhaustivity = .off
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.selectedBlock?.title, "Dinner")
        XCTAssertNil(store.state.heldMinute, "used once")
    }

    func testLoadsTheKidsWeekdayTemplate() async {
        let store = await loaded()
        XCTAssertEqual(store.state.edit.knobs.map(\.minute), [390, 450, 900, 960, 1020, 1110, 1155, 1200])
    }

    func testDraggingADinnerKnobShowsTheTimeAndTheEffect() async {
        let store = await loaded()
        let index = knob(store, at: 1155)
        await store.send(.knobDragged(index: index, minute: 1168))
        XCTAssertEqual(store.state.hub.time, "7:30 pm")
        XCTAssertEqual(store.state.hub.above, "Dinner ends")
        XCTAssertEqual(store.state.hub.below, "Shower starts")
        XCTAssertEqual(store.state.dragOrigin, 1155)
        XCTAssertNil(store.state.message, "layout v38: no neighbour-effect line")
        XCTAssertEqual(store.state.haptics.steps, 1, "one 5-minute step, not on the hour")
        await store.send(.knobReleased(index))
        XCTAssertNil(store.state.dragging)
        XCTAssertEqual(store.state.selectedBlock?.title, "Dinner")
    }

    /// Board G1: the dragged knob's time field on the slice card is outlined in pickBlue.
    func testDraggedKnobOutlinesItsTimeField() async {
        let store = await loaded()
        await store.send(.sliceTapped(start: 1110))
        XCTAssertEqual(store.state.selectedBlock?.title, "Dinner")
        XCTAssertFalse(store.state.isStartDragged)
        XCTAssertFalse(store.state.isEndDragged)
        await store.send(.knobDragged(index: knob(store, at: 1155), minute: 1160))
        XCTAssertFalse(store.state.isStartDragged)
        XCTAssertTrue(store.state.isEndDragged, "Dinner | Shower is Dinner's end")
        await store.send(.knobReleased(0))
        XCTAssertFalse(store.state.isEndDragged)
        await store.send(.knobDragged(index: knob(store, at: 1110), minute: 1100))
        XCTAssertTrue(store.state.isStartDragged, "the knob before Dinner is its start")
        XCTAssertFalse(store.state.isEndDragged)
        await store.send(.knobReleased(0))
        await store.send(.knobDragged(index: knob(store, at: 450), minute: 460))
        XCTAssertFalse(store.state.isStartDragged, "a knob away from the selected slice outlines neither")
        XCTAssertFalse(store.state.isEndDragged)
    }

    func testLimitsBump() async {
        let store = await loaded()
        await store.send(.knobDragged(index: knob(store, at: 1155), minute: 1250))
        XCTAssertEqual(store.state.edit.blocks.first { $0.title == "Shower" }?.start, 1185)
        XCTAssertGreaterThan(store.state.haptics.bumps, 0)
    }

    /// Layout v37: School's start moves; on Every time it moves School's hours with it.
    func testMovingSchoolForAllDaysMovesItsHours() async {
        let savedKids = LockIsolated<[Kid]>([])
        let store = await loaded(savedKids: savedKids)
        await store.send(.scopeTapped(.allDays))
        await store.send(.knobDragged(index: knob(store, at: 450), minute: 480))
        await store.send(.knobReleased(knob(store, at: 480)))
        XCTAssertEqual(store.state.edit.blocks.first { $0.kind == .school }?.start, 480)
        await store.send(.scopeTapped(.thisDay))
        await store.send(.saveTapped)
        await store.send(.fromWhenSaveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(savedKids.value.last?.school?.start, 480)
        XCTAssertEqual(savedKids.value.last?.school?.end, 900)
    }

    /// Spec G5 "What Settings shows meanwhile", #255: School moved on Every time from a later day keeps
    /// today's hours; the new ones wait for that day on the kid, and the version saved from it keeps
    /// today's School (the date reads the waiting hours).
    func testMovingSchoolFromALaterDayWaits() async {
        let savedKids = LockIsolated<[Kid]>([]), saved = LockIsolated<[Routine]>([])
        let store = await loaded(saved: saved, savedKids: savedKids)
        await store.send(.scopeTapped(.allDays))
        await store.send(.knobDragged(index: knob(store, at: 450), minute: 480))
        await store.send(.knobReleased(knob(store, at: 480)))
        await store.send(.saveTapped)
        await store.send(.fromWhenPicked(.next))
        await store.send(.fromWhenSaveTapped)
        await store.receive(\.saved)
        let wednesday = Day(year: 2026, month: 11, day: 11)
        XCTAssertEqual(savedKids.value.last?.school, SeedData.kidA.school, "today's hours stay")
        XCTAssertEqual(savedKids.value.last?.pendingHours?.from, wednesday)
        XCTAssertEqual(savedKids.value.last?.pendingHours?.school.start, 480)
        XCTAssertEqual(saved.value.last?.from, wednesday)
        XCTAssertEqual(saved.value.last?.blocks.first { $0.kind == .school }?.start, 450, "no copy of the waiting hours")
        let kid = try? XCTUnwrap(savedKids.value.last)
        let read = kid?.readingWaitingHours(SeedData.routines + saved.value) ?? []
        XCTAssertEqual(DayPlanner.template(for: SeedData.kidA.id, on: wednesday, routines: read, holidays: [],
                                           calendar: F.calendar)?.blocks.first { $0.kind == .school }?.start, 480)
    }

    /// A design answer to #255: School moved on Every time from today reaches a later version that
    /// follows the old record (its other edit stays).
    func testMovingSchoolFromTodayReachesLaterVersions() async {
        var later = SeedData.routines.first { $0.kid == SeedData.kidA.id && $0.dayType == .weekday }!
        later.from = Day(year: 2026, month: 11, day: 20)
        if let index = later.blocks.firstIndex(where: { $0.kind == .dinner }) {
            later.blocks[index - 1].end = 1125
            later.blocks[index].start = 1125
        }
        let saved = LockIsolated<[Routine]>([]), savedKids = LockIsolated<[Kid]>([])
        let store = await loaded(saved: saved, savedKids: savedKids, routines: SeedData.routines + [later])
        await store.send(.scopeTapped(.allDays))
        await store.send(.knobDragged(index: knob(store, at: 450), minute: 480))
        await store.send(.knobReleased(knob(store, at: 480)))
        await store.send(.saveTapped)
        await store.send(.fromWhenSaveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(savedKids.value.last?.school?.start, 480)
        let moved = saved.value.first { $0.from == later.from }
        XCTAssertEqual(moved?.blocks.first { $0.kind == .school }?.start, 480)
        XCTAssertEqual(moved?.blocks.first { $0.kind == .dinner }?.start, 1125, "its own edit stays")
    }

    /// School moved on Every time from a day after a waiting change starts from the record that applies
    /// then (the waiting one: its days stay), and replaces the waiting change from that day.
    func testMovingSchoolAfterTheWaitingDayStartsFromTheWaitingRecord() async {
        let wednesday = Day(year: 2026, month: 11, day: 11), thursday = Day(year: 2026, month: 11, day: 12)
        var waiting = SeedData.kidA.school!
        waiting.start = 480
        waiting.days = [.monday, .tuesday, .wednesday, .thursday]
        let kidA = SeedData.kidA.savingSchool(waiting, from: wednesday, today: tuesday)
        let savedKids = LockIsolated<[Kid]>([])
        let store = await loaded(savedKids: savedKids, kids: [kidA, SeedData.kidB])
        await store.send(.pickerDayTapped(thursday))
        await store.send(.scopeTapped(.allDays))
        await store.send(.knobDragged(index: knob(store, at: 480), minute: 510))
        await store.send(.knobReleased(knob(store, at: 510)))
        await store.send(.saveTapped)
        await store.send(.fromWhenSaveTapped)
        await store.receive(\.saved)
        let pending = savedKids.value.last?.pendingHours
        XCTAssertEqual(pending?.from, thursday)
        XCTAssertEqual(pending?.school.start, 510)
        XCTAssertEqual(pending?.school.days, waiting.days, "the waiting record's days stay")
        XCTAssertEqual(savedKids.value.last?.school, SeedData.kidA.school, "today's record stays")
    }

    /// While a change waits, a This day edit on a later day stores today's School (never a copy).
    func testAThisDayEditAfterTheWaitingDayStoresTodaysSchool() async {
        let wednesday = Day(year: 2026, month: 11, day: 11), thursday = Day(year: 2026, month: 11, day: 12)
        var waiting = SeedData.kidA.school!
        waiting.start = 480
        let kidA = SeedData.kidA.savingSchool(waiting, from: wednesday, today: tuesday)
        let saved = LockIsolated<[Routine]>([])
        let store = await loaded(saved: saved, kids: [kidA, SeedData.kidB])
        await store.send(.pickerDayTapped(thursday))
        await store.send(.knobDragged(index: knob(store, at: 1110), minute: 1125))
        await store.send(.knobReleased(knob(store, at: 1125)))
        await store.send(.saveTapped)
        await store.receive(\.saved)
        let own = saved.value.last
        XCTAssertEqual(own?.onlyOn, thursday)
        XCTAssertEqual(own?.blocks.first { $0.kind == .school }?.start, 450, "today's School is stored")
        XCTAssertEqual(own?.blocks.first { $0.kind == .dinner }?.start, 1125)
        XCTAssertEqual(store.state.edit.blocks.first { $0.kind == .school }?.start, 480, "still read by date")
    }

    /// #255 S1: while a change waits from Wed, Thu's clock shows the waiting School; another slice saved
    /// on Every time from Thu keeps today's School in the store, so a cancel leaves Thu on today's hours
    /// with the other edit.
    func testAnotherEditAfterTheWaitingDayStoresTodaysSchool() async {
        let wednesday = Day(year: 2026, month: 11, day: 11), thursday = Day(year: 2026, month: 11, day: 12)
        var later = SeedData.kidA.school!
        later.start = 480
        let kidA = SeedData.kidA.savingSchool(later, from: wednesday, today: tuesday)
        let saved = LockIsolated<[Routine]>([])
        let store = await loaded(saved: saved, kids: [kidA, SeedData.kidB])
        XCTAssertEqual(store.state.edit.blocks.first { $0.kind == .school }?.start, 450, "today: today's hours")
        await store.send(.pickerDayTapped(thursday))
        XCTAssertEqual(store.state.edit.blocks.first { $0.kind == .school }?.start, 480, "Thu reads the waiting hours")
        await store.send(.scopeTapped(.allDays))
        await store.send(.knobDragged(index: knob(store, at: 1110), minute: 1125))
        await store.send(.knobReleased(knob(store, at: 1125)))
        await store.send(.saveTapped)
        XCTAssertEqual(store.state.allDaysFrom, thursday)
        await store.send(.fromWhenSaveTapped)
        await store.receive(\.saved)
        let version = saved.value.last
        XCTAssertEqual(version?.from, thursday)
        XCTAssertEqual(version?.blocks.first { $0.kind == .school }?.start, 450, "today's School is stored")
        XCTAssertEqual(version?.blocks.first { $0.kind == .dinner }?.start, 1125)
        XCTAssertEqual(store.state.edit.blocks.first { $0.kind == .school }?.start, 480, "still read by date")
        var cancelled = kidA
        cancelled.pendingHours = nil
        let after = DayPlanner.template(for: kidA.id, on: thursday,
                                        routines: cancelled.readingWaitingHours(SeedData.routines + saved.value),
                                        holidays: [], calendar: F.calendar)
        XCTAssertEqual(after?.blocks.first { $0.kind == .school }?.start, 450)
        XCTAssertEqual(after?.blocks.first { $0.kind == .dinner }?.start, 1125, "the other edit stays")
    }

    /// Spec "Add between two slices": a "+" on every shared knob, all the time (none beside free
    /// time); the knob being dragged hides its "+".
    func testPlusOnEverySharedKnob() async {
        let store = await loaded()
        XCTAssertEqual(store.state.addButtons.map(\.minute), [390, 450, 900, 1110, 1155, 1200])
        await store.send(.knobDragged(index: knob(store, at: 1155), minute: 1160))
        XCTAssertFalse(store.state.addButtons.contains { $0.minute == 1160 }, "the dragged knob hides its +")
        XCTAssertEqual(store.state.addButtons.count, 5)
        await store.send(.knobReleased(0))
        XCTAssertTrue(store.state.addButtons.contains { $0.minute == 1160 })
    }

    /// Spec "Add between two slices": a 15-minute Shower keeps both "+": Dinner | Shower on the
    /// outer ring, Shower | Sleep one ring in.
    func testTouchingPlusTakeTheNextRing() async {
        let store = await loaded()
        await store.send(.knobDragged(index: knob(store, at: 1155), minute: 1185))
        await store.send(.knobReleased(0))
        XCTAssertEqual(store.state.addButtons.first { $0.minute == 1185 }?.ring, 0)
        XCTAssertEqual(store.state.addButtons.first { $0.minute == 1200 }?.ring, 1)
    }

    /// Spec "Add between two slices": a new 30-minute item keeps both of its "+", on two rings;
    /// dragging one hides only its own "+", the others keep their rings. Dragging the item's end
    /// moves only the item, so the Shower under it lights neither of its time fields.
    func testANewThirtyMinuteItemKeepsBothPlus() async throws {
        let store = await loaded()
        let plus = try XCTUnwrap(store.state.addButtons.first { $0.minute == 1155 })
        await store.send(.addBetweenTapped(plus.knob))
        await store.send(.newSlicePicturePicked("actPiano"))
        let rings = { Dictionary(uniqueKeysWithValues: store.state.addButtons.map { ($0.minute, $0.ring) }) }
        XCTAssertEqual(rings()[1155], 0)
        XCTAssertEqual(rings()[1185], 1)
        XCTAssertEqual(rings()[1200], 0)
        await store.send(.sliceTapped(start: 1185))
        XCTAssertEqual(store.state.selectedBlock?.title, "Shower")
        await store.send(.knobDragged(index: knob(store, at: 1185), minute: 1185))
        XCTAssertNil(rings()[1185], "the dragged knob hides its +")
        XCTAssertEqual(rings()[1200], 0, "the others keep their rings")
        XCTAssertFalse(store.state.isStartDragged, "the item's end is not the Shower's start")
        XCTAssertFalse(store.state.isEndDragged)
    }

    /// Spec "Tapping +": the "+" between Dinner and Shower covers Shower's first 30 minutes as a new
    /// item (This day: just once); the template underneath stays. Closing the card before a picture
    /// is picked leaves nothing behind.
    func testAddBetweenIsAJustOnceItemOnThisDay() async throws {
        let writes = Writes()
        let store = await loaded(writes: writes)
        let before = store.state.edit.blocks
        let plus = try XCTUnwrap(store.state.addButtons.first { $0.minute == 1155 })
        await store.send(.addBetweenTapped(plus.knob))
        XCTAssertEqual(store.state.newSlice?.start, 1155)
        XCTAssertEqual(store.state.newSlice?.end, 1185)
        XCTAssertEqual(store.state.hub.above, "New")
        XCTAssertEqual(store.state.hub.below, "until 7:45 pm")
        await store.send(.sliceTapped(start: 0))
        XCTAssertNil(store.state.newSlice)
        XCTAssertFalse(store.state.canUndo, "nothing was added")

        await store.send(.addBetweenTapped(plus.knob))
        await store.send(.newSlicePicturePicked("actPiano"))
        XCTAssertEqual(store.state.edit.blocks, before, "never a template change")
        XCTAssertEqual(store.state.sectors.first { $0.start == 1155 }?.iconName, "actPiano")
        XCTAssertEqual(store.state.selectedTitle, "Piano")
        await store.send(.saveTapped)
        XCTAssertNil(store.state.fromWhen, "This day asks no from when")
        await store.receive(\.saved)
        XCTAssertTrue(writes.routines.value.isEmpty, "the template did not change")
        let piano = try XCTUnwrap(writes.items.value.first)
        XCTAssertEqual(piano.recurrence, .once(tuesday))
        XCTAssertEqual([piano.start, piano.end], [1155, 1185])
        XCTAssertEqual(store.state.items.map(\.id), [piano.id])
        XCTAssertFalse(store.state.canUndo)
        XCTAssertEqual(store.state.selectedTitle, "Piano", "still picked after the save")
    }

    /// Spec "Tapping +" on free paper: the first hour, an every-week item on the day's weekday on
    /// Every time (from G5's date). A typed name sticks; Undo takes the new item back, card and all.
    func testFreePaperPlusOnAllDaysIsAnEveryWeekItem() async throws {
        let writes = Writes()
        let store = await loaded(writes: writes)
        await store.send(.scopeTapped(.allDays))
        await store.send(.plusTapped(start: 960))
        XCTAssertEqual(store.state.newSlice?.start, 960)
        XCTAssertEqual(store.state.newSlice?.end, 1020)
        XCTAssertEqual(store.state.newSlicePictures.count, 7)
        await store.send(.newSlicePicturePicked("actPiano"))
        XCTAssertEqual(store.state.newSlicePictures.first, .actPiano, "the picked picture comes first")
        await store.send(.newSliceNameChanged("Piano with Mum and Dad"))
        await store.send(.newSlicePicturePicked("actMusic"))
        let item = try XCTUnwrap(store.state.selectedItem)
        XCTAssertEqual(item.title, "Piano with Mum", "14 characters at most")
        XCTAssertEqual(item.iconName, "actMusic")
        XCTAssertTrue(item.isRepeating)
        XCTAssertEqual([store.state.startLabel, store.state.endLabel], ["4:00 pm", "5:00 pm"],
                       "a new slice on the clock is the selected one, so its card has its times")
        XCTAssertEqual([store.state.canUndo, store.state.canRedo], [true, false])
        // Undo takes the new item back in one step, card and all.
        await store.send(.undoTapped)
        XCTAssertNil(store.state.newSlice)
        XCTAssertTrue(store.state.edit.items.isEmpty)
        XCTAssertEqual([store.state.canUndo, store.state.canRedo], [false, true], "Undo off, Redo on")
        await store.send(.redoTapped)
        XCTAssertEqual([store.state.canUndo, store.state.canRedo], [true, false])
        XCTAssertEqual(store.state.fromWhenChoice, .today, "the card shows Today until it opens")
        await store.send(.saveTapped)
        XCTAssertEqual(store.state.fromWhen, .today, "a new series asks from when")
        await store.send(.fromWhenPicked(.next))
        XCTAssertEqual(store.state.fromWhenChoice, .next)
        await store.send(.fromWhenSaveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(writes.items.value.first?.recurrence,
                       .weekly([.tuesday], from: Day(year: 2026, month: 11, day: 11), until: nil))
    }

    /// A new item picked again before Save still follows its tabs: Every time makes it every week.
    func testANewItemFollowsItsTabsUntilSave() async throws {
        let writes = Writes()
        let store = await loaded(writes: writes)
        let plus = try XCTUnwrap(store.state.addButtons.first { $0.minute == 1155 })
        await store.send(.addBetweenTapped(plus.knob))
        await store.send(.newSlicePicturePicked("actPiano"))
        await store.send(.sliceTapped(start: 0))
        await store.send(.sliceTapped(start: 1155))
        XCTAssertTrue(store.state.showsScopeTabs)
        await store.send(.scopeTapped(.allDays))
        XCTAssertEqual(store.state.selectedItem?.isRepeating, true)
        await store.send(.saveTapped)
        XCTAssertEqual(store.state.fromWhen, .today)
        await store.send(.fromWhenSaveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(writes.items.value.first?.recurrence, .weekly([.tuesday], from: tuesday, until: nil))
    }

    /// Review (PR 174): a second "+" opens its own card; its tabs never change the item added before.
    func testASecondPlusLeavesTheFirstItemAlone() async throws {
        let writes = Writes()
        let store = await loaded(writes: writes)
        let first = try XCTUnwrap(store.state.addButtons.first { $0.minute == 1155 })
        await store.send(.addBetweenTapped(first.knob))
        await store.send(.newSlicePicturePicked("actPiano"))
        let second = try XCTUnwrap(store.state.addButtons.first { $0.minute == 900 })
        await store.send(.addBetweenTapped(second.knob))
        await store.send(.scopeTapped(.allDays))
        XCTAssertEqual(store.state.shownScope, .allDays, "the new card's tab")
        await store.send(.newSlicePicturePicked("actArt"))
        XCTAssertEqual(store.state.edit.items.map(\.isRepeating), [false, true], "Piano stays just once")
        await store.send(.saveTapped)
        await store.send(.fromWhenSaveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(writes.items.value.count, 2)
        XCTAssertEqual(writes.items.value.first?.title, "Piano")
        XCTAssertEqual(writes.items.value.first?.recurrence, .once(tuesday))
    }

    /// Review (PR 174): a new item's tabs show its own kind wherever the screen's tabs are, a new
    /// series asks G5 whatever tab is showing at Save, and its kind change is one Undo step.
    func testANewItemsTabsShowItsOwnKind() async throws {
        let store = await loaded()
        let plus = try XCTUnwrap(store.state.addButtons.first { $0.minute == 1155 })
        await store.send(.addBetweenTapped(plus.knob))
        await store.send(.newSlicePicturePicked("actPiano"))
        await store.send(.sliceTapped(start: 1110))
        await store.send(.scopeTapped(.allDays))
        await store.send(.sliceTapped(start: 1155))
        XCTAssertEqual(store.state.shownScope, .thisDay, "Piano is just once")
        XCTAssertFalse(store.state.needsFromWhen, "nothing every week yet")

        await store.send(.scopeTapped(.allDays))
        XCTAssertEqual(store.state.selectedItem?.isRepeating, true)
        await store.send(.knobDragged(index: knob(store, at: 1110), minute: 1100))
        await store.send(.knobReleased(0))
        await store.send(.undoTapped)
        XCTAssertEqual(store.state.edit.items.first?.isRepeating, true, "Undo of the drag keeps Piano's kind")
        await store.send(.sliceTapped(start: 1110))
        await store.send(.scopeTapped(.thisDay))
        XCTAssertTrue(store.state.needsFromWhen, "a new every-week series asks from when")
        await store.send(.undoTapped)
        XCTAssertEqual(store.state.edit.items.first?.isRepeating, false, "the kind change is its own step")
    }

    /// School's Remove leaves the clock, so unsaved changes ask G1d first; Save goes on to G7.
    func testSchoolRemoveAsksFirstWithUnsavedChanges() async throws {
        let store = await loaded()
        await store.send(.knobDragged(index: knob(store, at: 1155), minute: 1170))
        await store.send(.knobReleased(0))
        let school = try XCTUnwrap(store.state.edit.blocks.first { $0.kind == .school })
        await store.send(.sliceTapped(start: school.start))
        await store.send(.scopeTapped(.allDays))
        await store.send(.sliceActionTapped)
        XCTAssertTrue(store.state.isConfirmingLeave)
        XCTAssertEqual(store.state.pendingSwitch, .atHome)
        await store.send(.unsavedSaveTapped)
        await store.receive(\.saved)
        await store.receive(\.delegate.removeSchool)
    }

    /// Review case B (PR 174): Skip Play on This day and Remove Dinner on Every time; each is saved by
    /// its own scope. With G5 on tomorrow (Wed), this day keeps Dinner and has Play skipped.
    func testASkipAndARemoveSaveByTheirOwnScopes() async throws {
        let writes = Writes()
        let store = await loaded(writes: writes)
        await store.send(.sliceTapped(start: 1020))
        await store.send(.sliceActionTapped)
        await store.send(.scopeTapped(.allDays))
        await store.send(.sliceTapped(start: 1110))
        await store.send(.sliceActionTapped)
        XCTAssertEqual(store.state.selectedBlock?.kind, .free)
        await store.send(.saveTapped)
        await store.send(.fromWhenPicked(.next))
        await store.send(.fromWhenSaveTapped)
        await store.receive(\.saved)
        let series = try XCTUnwrap(writes.routines.value.first { $0.onlyOn == nil })
        XCTAssertEqual(series.from, Day(year: 2026, month: 11, day: 11))
        XCTAssertFalse(series.blocks.contains { $0.title == "Dinner" })
        XCTAssertFalse(series.blocks.contains(where: \.isSkipped))
        let own = try XCTUnwrap(writes.routines.value.first { $0.onlyOn == tuesday })
        XCTAssertEqual(own.blocks.first { $0.title == "Play" }?.isSkipped, true)
        XCTAssertTrue(own.blocks.contains { $0.title == "Dinner" }, "the Every time change starts Wednesday")
        XCTAssertTrue(store.state.edit.blocks.contains { $0.title == "Dinner" })
        XCTAssertEqual(store.state.edit.blocks.first { $0.title == "Play" }?.isSkipped, true)
    }

    /// Review (PR 174): Undo with the new card open takes back the last step; the card closes only
    /// when the item itself goes.
    func testUndoKeepsTheNewCardInStep() async throws {
        let store = await loaded()
        let plus = try XCTUnwrap(store.state.addButtons.first { $0.minute == 1155 })
        await store.send(.addBetweenTapped(plus.knob))
        await store.send(.newSlicePicturePicked("actPiano"))
        await store.send(.endPicked(tuesday.date(minute: 1175, calendar: F.calendar)))
        XCTAssertEqual(store.state.selectedItem?.end, 1175)
        await store.send(.undoTapped)
        XCTAssertNotNil(store.state.newSlice, "the item is still there, so its card stays")
        XCTAssertEqual(store.state.selectedItem?.end, 1185)
        await store.send(.undoTapped)
        XCTAssertNil(store.state.newSlice)
        XCTAssertTrue(store.state.edit.items.isEmpty)
    }

    /// Review (PR 174): a second Save while one runs does nothing.
    func testSaveRunsOnce() async {
        let count = LockIsolated(0)
        let clock = TestClock()
        let store = await loaded()
        // The store's write takes a moment, so the second tap comes while the first save runs.
        store.dependencies.scheduleStore.saveRoutine = { _ in
            count.withValue { $0 += 1 }
            try await clock.sleep(for: .seconds(1))
        }
        await store.send(.knobDragged(index: knob(store, at: 1155), minute: 1170))
        await store.send(.knobReleased(0))
        await store.send(.saveTapped)
        XCTAssertTrue(store.state.isSaving)
        await store.send(.saveTapped)
        await clock.run()
        await store.receive(\.saved)
        XCTAssertFalse(store.state.isSaving)
        XCTAssertEqual(count.value, 1)
    }

    /// Spec G1 "One card": Remove on Every time makes a day slice free time at once (no confirm); the
    /// free paper has neither action.
    func testRemoveADaySliceOnAllDays() async throws {
        let store = await loaded()
        let play = store.state.edit.blocks.first { $0.title == "Play" }!
        await store.send(.sliceTapped(start: play.start))
        XCTAssertEqual(store.state.sliceAction, .skip, "This day offers Skip this day")
        XCTAssertNil(store.state.detailsTitle, "a day slice has no form")
        await store.send(.scopeTapped(.allDays))
        XCTAssertEqual(store.state.sliceActionTitle, "Remove")
        await store.send(.sliceActionTapped)
        XCTAssertNil(store.state.removing)
        XCTAssertEqual(store.state.selectedBlock?.kind, .free)
        XCTAssertNil(store.state.sliceAction, "free time has neither action")
        XCTAssertNil(store.state.selectedPicture)
        await store.send(.undoTapped)
        XCTAssertEqual(store.state.edit.blocks.first { $0.start == play.start }?.title, "Play")
        XCTAssertFalse(store.state.edit.isChanged)
    }

    /// Board G1g: a slice skipped this day stays faded with "Skipped / this day"; Bring back undoes it;
    /// This day saves the skip, Every time never does.
    func testSkipThisDayAndBringBack() async throws {
        let saved = LockIsolated<[Routine]>([])
        let store = await loaded(saved: saved)
        let play = try XCTUnwrap(store.state.edit.blocks.first { $0.title == "Play" })
        await store.send(.sliceTapped(start: play.start))
        XCTAssertEqual(store.state.sliceActionTitle, "Skip this day")
        await store.send(.sliceActionTapped)
        XCTAssertTrue(store.state.isSelectedSkipped)
        XCTAssertNil(store.state.sliceAction, "a skipped slice offers only Bring back")
        XCTAssertEqual(store.state.hub.above, "Play")
        XCTAssertEqual(store.state.hub.time, "Skipped")
        XCTAssertEqual(store.state.hub.below, "this day")
        XCTAssertEqual(store.state.sectors.first { $0.start == play.start }?.isFaded, true)
        await store.send(.bringBackTapped)
        XCTAssertFalse(store.state.isSelectedSkipped)
        await store.send(.sliceActionTapped)
        await store.send(.saveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(saved.value.last?.onlyOn, tuesday)
        XCTAssertEqual(saved.value.last?.blocks.first { $0.start == play.start }?.isSkipped, true)
        XCTAssertTrue(store.state.isSelectedSkipped, "the clock shows the saved day: Play skipped")
        // Every time never offers a skip.
        await store.send(.scopeTapped(.allDays))
        await store.send(.sliceTapped(start: store.state.edit.blocks.first { $0.title == "Dinner" }!.start))
        XCTAssertEqual(store.state.sliceAction, .remove)
    }

    func testLeavingWithChangesAsksFirst() async {
        let store = await loaded()
        await store.send(.knobDragged(index: knob(store, at: 1155), minute: 1170))
        await store.send(.backTapped)
        XCTAssertTrue(store.state.isConfirmingLeave)
        // G1d has Save and Cancel only: to drop the change, Cancel, Undo, then leave.
        await store.send(.leaveCancelled)
        await store.send(.undoTapped)
        await store.send(.backTapped)
        XCTAssertFalse(store.state.isConfirmingLeave)
        await store.receive(\.delegate.finished)
    }

    /// Board G1c: the day button opens two weeks from the day's Monday; a Sunday shows the Sun template.
    func testPickingADayLoadsItsTemplate() async {
        let store = await loaded()
        XCTAssertEqual(store.state.dayButtonToday, "Today")
        XCTAssertEqual(store.state.dayButtonDate, "Tue 10 Nov")
        await store.send(.dayButtonTapped)
        XCTAssertEqual(store.state.pickerDays.first, Day(year: 2026, month: 11, day: 9))
        XCTAssertEqual(store.state.pickerDays.count, 14)
        XCTAssertEqual(store.state.pickerMonth, "November")
        XCTAssertEqual(store.state.pickerWeekdays, ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"],
                       "layout v66: the weekdays once, in a header row")
        XCTAssertEqual(store.state.pickerWeeks.flatMap { $0 }.map(\.day).prefix(3), [9, 10, 11])
        await store.send(.pickerPageTapped(1))
        XCTAssertEqual(store.state.pickerDays.first, Day(year: 2026, month: 11, day: 23))
        await store.send(.pickerDayTapped(Day(year: 2026, month: 11, day: 15)))
        XCTAssertNil(store.state.pickerStart)
        XCTAssertNil(store.state.dayButtonToday)
        XCTAssertEqual(store.state.dayButtonDate, "Sun 15 Nov")
        XCTAssertEqual(store.state.dayType, .sunday)
        XCTAssertEqual(store.state.edit.blocks.first?.end, 450, "the weekend shape wakes at 7:30 am")
        await store.send(.dayButtonTapped)
        await store.send(.pickerTodayTapped)
        XCTAssertEqual(store.state.day, tuesday)
    }

    /// Spec "Edit scope": a drag saves for this day only unless Every time is picked.
    func testSaveThisDayKeepsOtherDays() async {
        let saved = LockIsolated<[Routine]>([])
        let store = await loaded(saved: saved)
        await store.send(.knobDragged(index: knob(store, at: 1155), minute: 1170))
        await store.send(.knobReleased(knob(store, at: 1170)))
        XCTAssertEqual(store.state.scope, .thisDay)
        await store.send(.saveTapped)
        await store.receive(\.saved)
        XCTAssertFalse(store.state.canUndo, "saved: nothing to undo, and the clock stays (board G1)")
        XCTAssertEqual(saved.value.first?.onlyOn, tuesday)
        XCTAssertEqual(saved.value.first?.blocks.first { $0.title == "Dinner" }?.end, 1170)
        // The next Tuesday still has the usual template.
        await store.send(.dayButtonTapped)
        await store.send(.pickerPageTapped(1))
        await store.send(.pickerDayTapped(Day(year: 2026, month: 11, day: 24)))
        XCTAssertEqual(store.state.edit.blocks.first { $0.title == "Dinner" }?.end, 1155)
    }

    /// Spec G5 (layout v80): on a later day G1's card opens with that day picked, on Date unless it
    /// is the middle tab's day; Save writes the template from that day.
    func testFromWhenOpensOnTheDayBeingLookedAt() async {
        let saved = LockIsolated<[Routine]>([])
        let store = await loaded(saved: saved)
        await store.send(.dayButtonTapped)
        await store.send(.pickerDayTapped(Day(year: 2026, month: 11, day: 12)))
        XCTAssertEqual(store.state.day, Day(year: 2026, month: 11, day: 12))
        await store.send(.scopeTapped(.allDays))
        await store.send(.knobDragged(index: knob(store, at: 1155), minute: 1170))
        await store.send(.knobReleased(0))
        await store.send(.saveTapped)
        XCTAssertEqual(store.state.fromWhen, .date, "Thu 12 Nov is not the middle tab's day (tomorrow)")
        XCTAssertEqual(store.state.fromWhenDateLabel, "12 Nov")
        XCTAssertEqual(store.state.editorDay, Day(year: 2026, month: 11, day: 12), "Details opens on this day")
        await store.send(.fromWhenSaveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(saved.value.first?.from, Day(year: 2026, month: 11, day: 12))
    }

    /// Spec G5: tomorrow on the clock opens on the middle tab.
    func testFromWhenOpensOnTomorrowsTab() async {
        let store = await loaded()
        await store.send(.dayButtonTapped)
        await store.send(.pickerDayTapped(Day(year: 2026, month: 11, day: 11)))
        await store.send(.scopeTapped(.allDays))
        await store.send(.knobDragged(index: knob(store, at: 1155), minute: 1170))
        await store.send(.knobReleased(0))
        await store.send(.saveTapped)
        XCTAssertEqual(store.state.fromWhen, .next, "tomorrow is the middle tab (today: testSaveAllDaysFromTheDay)")
        XCTAssertEqual(store.state.allDaysFrom, Day(year: 2026, month: 11, day: 11))
    }

    /// The List's rows open G2 / G4 on Today (no day being looked at).
    func testTheListOpensItemsWithNoShownDay() async {
        let store = await loaded()
        XCTAssertEqual(store.state.editorDay, tuesday)
        await store.send(.listTapped)
        XCTAssertTrue(store.state.showsList)
        XCTAssertNil(store.state.editorDay)
    }

    func testSaveAllDaysFromTheDay() async {
        let saved = LockIsolated<[Routine]>([])
        let store = await loaded(saved: saved)
        await store.send(.scopeTapped(.allDays))
        await store.send(.knobDragged(index: knob(store, at: 1155), minute: 1170))
        await store.send(.knobReleased(0))
        await store.send(.scopeTapped(.thisDay))
        await store.send(.saveTapped)
        XCTAssertEqual(store.state.fromWhen, .today, "an Every time drag asks from when (board G5), whatever tab shows")
        XCTAssertEqual(store.state.fromWhenTabs.map(\.1), ["Today", "Tomorrow", "Date"], "never \"Next Wed\"")
        await store.send(.fromWhenPicked(.next))
        await store.send(.fromWhenSaveTapped)
        await store.receive(\.saved)
        XCTAssertNil(store.state.fromWhen)
        XCTAssertNil(saved.value.first?.onlyOn)
        XCTAssertEqual(saved.value.first?.from, Day(year: 2026, month: 11, day: 11))
        XCTAssertEqual(saved.value.first?.dayType, .weekday)
        XCTAssertEqual(saved.value.count, 1, "no own template for this day")
    }

    /// Spec "G1 as built": the card is never empty: the slice now on today, else the day's first.
    func testOpensWithASlicePicked() async {
        let store = await loaded()
        XCTAssertEqual(store.state.selectedBlock?.title, "School", "10:00 am on a school day")
        await store.send(.dayButtonTapped)
        await store.send(.pickerDayTapped(Day(year: 2026, month: 11, day: 11)))
        XCTAssertEqual(store.state.selected, .block(0), "another day opens on its first slice")
    }

    /// Board G1d: "Save the changes?" names the change; Save saves, then goes on.
    func testUnsavedCardSavesThenSwitchesDay() async {
        let saved = LockIsolated<[Routine]>([])
        let store = await loaded(saved: saved)
        await store.send(.knobDragged(index: knob(store, at: 1155), minute: 1170))
        await store.send(.knobReleased(0))
        await store.send(.dayButtonTapped)
        await store.send(.pickerDayTapped(Day(year: 2026, month: 11, day: 11)))
        XCTAssertTrue(store.state.isConfirmingLeave)
        XCTAssertEqual(store.state.unsavedLine, "Dinner 6:30 pm %@ 7:30 pm, this day")
        await store.send(.unsavedSaveTapped)
        await store.receive(\.saveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(saved.value.count, 1)
        XCTAssertEqual(store.state.day, Day(year: 2026, month: 11, day: 11))
        XCTAssertFalse(store.state.edit.isChanged)
    }

    // MARK: One card for everything on the clock (spec G1, 2026-11-21)

    /// Swimming every Tuesday 5:00–6:00 pm, on top of Play.
    private let swimID = UUID(uuidString: "00000000-0000-0000-0000-00000000C001")!
    private var swim: ScheduleItem { F.weekly(days: [.tuesday], start: 1020, end: 1080, id: swimID) }

    /// An every-week item opens the same card: Skip this day on This day; on Every time Remove asks
    /// first, takes it off the clock until Undo, and Save ends the series from G5's date.
    func testAnEveryWeekItemSkipsOrEndsItsSeries() async throws {
        let writes = Writes()
        let store = await loaded(items: [swim], writes: writes)
        XCTAssertEqual(store.state.sectors.first { $0.start == 1020 }?.iconName, "actSwim", "on top of Play")
        XCTAssertEqual(store.state.sectors.first { $0.start == 1080 }?.iconName, "blocks", "Play shows around it")
        await store.send(.sliceTapped(start: 1020))
        XCTAssertEqual(store.state.selectedTitle, "Swimming")
        XCTAssertTrue(store.state.showsScopeTabs)
        XCTAssertEqual(store.state.sliceActionTitle, "Skip this day")
        XCTAssertEqual(store.state.detailsTitle, "Details %@")
        XCTAssertEqual(store.state.addButtons.map(\.minute), [390, 450, 900, 1080, 1110, 1155, 1200],
                       "Swimming's end has a +")
        XCTAssertEqual(store.state.addButtons.first { $0.minute == 1110 }?.ring, 1,
                       "Play | Dinner, 30 minutes later, one ring in")

        await store.send(.scopeTapped(.allDays))
        XCTAssertEqual(store.state.sliceActionTitle, "Remove")
        await store.send(.sliceActionTapped)
        XCTAssertEqual(store.state.removeTitle, "Remove Swimming every week?")
        XCTAssertEqual([store.state.removeAccept, store.state.removeKeep], ["Remove", "Keep"])
        await store.send(.removeCancelled)
        XCTAssertNil(store.state.removeTitle)
        XCTAssertFalse(store.state.canUndo, "Keep changes nothing")
        await store.send(.sliceActionTapped)
        await store.send(.removeConfirmed)
        XCTAssertNil(store.state.sectors.first { $0.iconName == "actSwim" })
        XCTAssertEqual(store.state.selectedBlock?.title, "Play", "the slice underneath is picked")
        XCTAssertEqual(store.state.unsavedLine, "Swimming 5:00 pm %@ 6:00 pm, every time")
        await store.send(.undoTapped)
        XCTAssertNotNil(store.state.sectors.first { $0.iconName == "actSwim" }, "Undo brings it back")
        await store.send(.redoTapped)
        await store.send(.saveTapped)
        XCTAssertEqual(store.state.fromWhen, .today)
        await store.send(.fromWhenPicked(.next))
        await store.send(.fromWhenSaveTapped)
        await store.receive(\.saved)
        XCTAssertTrue(writes.routines.value.isEmpty)
        XCTAssertEqual(writes.items.value.first?.recurrence.range?.until, tuesday, "ends before Wednesday")
    }

    func testSkippingAnEveryWeekItemThisDay() async {
        let writes = Writes()
        let store = await loaded(items: [swim], writes: writes)
        await store.send(.sliceTapped(start: 1020))
        await store.send(.sliceActionTapped)
        XCTAssertTrue(store.state.isSelectedSkipped)
        XCTAssertEqual(store.state.sectors.first { $0.start == 1020 }?.isFaded, true, "faded, still on the clock")
        XCTAssertEqual(store.state.hub.time, "Skipped")
        await store.send(.saveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(writes.items.value.first?.skippedDays, [tuesday])
        XCTAssertTrue(writes.routines.value.isEmpty, "no own template for the day")
        XCTAssertTrue(store.state.isSelectedSkipped, "after the save it stays on the clock for Bring back")
    }

    /// A just-once item has one date: no scope tabs and one "Remove" ("Remove Party?").
    func testAJustOnceItemHasOneRemove() async {
        let writes = Writes()
        let party = F.once("Party", on: tuesday, start: 960, end: 1020, audience: .kid(SeedData.kidA.id))
        let store = await loaded(items: [party], writes: writes)
        await store.send(.sliceTapped(start: 960))
        XCTAssertEqual(store.state.selectedTitle, "Party")
        XCTAssertFalse(store.state.showsScopeTabs)
        XCTAssertEqual(store.state.sliceActionTitle, "Remove", "on This day too")
        await store.send(.sliceActionTapped)
        XCTAssertEqual(store.state.removeTitle, "Remove Party?")
        await store.send(.removeConfirmed)
        await store.send(.saveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(writes.deleted.value, [party.id])
        XCTAssertTrue(store.state.items.isEmpty)
    }

    /// School: Skip this day in one tap; Remove on Every time opens G7 with At home picked (spec G1
    /// "One card", e39b24d), never a template-only removal.
    func testSchoolSkipsInOneTapAndRemoveOpensG7() async throws {
        let store = await loaded()
        let school = try XCTUnwrap(store.state.edit.blocks.first { $0.kind == .school })
        await store.send(.sliceTapped(start: school.start))
        XCTAssertEqual(store.state.sliceAction, .skip)
        XCTAssertEqual(store.state.detailsTitle, "Details %@")
        await store.send(.sliceActionTapped)
        XCTAssertTrue(store.state.isSelectedSkipped)
        await store.send(.undoTapped)
        await store.send(.scopeTapped(.allDays))
        await store.send(.sliceActionTapped)
        XCTAssertNil(store.state.removeTitle, "no confirm: G7 is the next step")
        await store.receive(\.delegate.removeSchool, SeedData.kidA.id)
        XCTAssertTrue(store.state.edit.blocks.contains { $0.kind == .school }, "the clock does not free it")
        XCTAssertFalse(store.state.canUndo)
    }

    /// Every-month items confirm "every month" (spec G1 "One card").
    func testAMonthlyItemAsksEveryMonth() async {
        let club = ScheduleItem(id: swimID, title: "Book club", iconName: "actStory", audience: .kid(SeedData.kidA.id),
                                start: 1020, end: 1080,
                                recurrence: .monthly(.nthWeekday(2, .tuesday), from: Day(year: 2026, month: 11, day: 1),
                                                     until: nil),
                                skippedDays: [], skipsHolidays: false, showsStar: false)
        let store = await loaded(items: [club])
        await store.send(.sliceTapped(start: 1020))
        await store.send(.scopeTapped(.allDays))
        await store.send(.sliceActionTapped)
        XCTAssertEqual(store.state.removeTitle, "Remove Book club every month?")
    }

    /// "Details ›" opens the item's form, after G1d when something is unsaved.
    func testDetailsOpensTheFormAfterAskingFirst() async {
        let store = await loaded(items: [swim])
        await store.send(.sliceTapped(start: 1020))
        await store.send(.detailsTapped)
        await store.receive(\.delegate.openItem)
        await store.send(.knobDragged(index: knob(store, at: 1155), minute: 1170))
        await store.send(.knobReleased(0))
        await store.send(.sliceTapped(start: 1020))
        await store.send(.detailsTapped)
        XCTAssertTrue(store.state.isConfirmingLeave)
        XCTAssertEqual(store.state.pendingSwitch, .item(swimID))
        await store.send(.unsavedSaveTapped)
        await store.receive(\.saved)
        await store.receive(\.delegate.openItem)
        // School's card opens G4.
        await store.send(.sliceTapped(start: 450))
        await store.send(.detailsTapped)
        await store.receive(\.delegate.openSchool)
    }

    /// Review (PR 174): Details after G1d's Save and G5's split opens the series now on the clock
    /// (the new part), not the old one that ends yesterday.
    func testDetailsAfterASplitOpensTheNewSeries() async throws {
        let store = await loaded(items: [swim])
        await store.send(.scopeTapped(.allDays))
        await store.send(.knobDragged(index: knob(store, at: 1080), minute: 1095))
        await store.send(.knobReleased(0))
        await store.send(.detailsTapped)
        XCTAssertTrue(store.state.isConfirmingLeave)
        await store.send(.unsavedSaveTapped)
        await store.receive(\.saveTapped)
        XCTAssertEqual(store.state.fromWhen, .today)
        await store.send(.fromWhenSaveTapped)
        await store.receive(\.saved)
        let opened = try XCTUnwrap(store.state.selectedItem?.id)
        XCTAssertNotEqual(opened, swimID)
        await store.receive(\.delegate.openItem, opened)
    }

    /// An item's edge is a drag knob: it moves only the item, and This day keeps the time for the day.
    func testDraggingAnItemEdgeMovesOnlyTheItem() async throws {
        let writes = Writes()
        let store = await loaded(items: [swim], writes: writes)
        await store.send(.knobDragged(index: knob(store, at: 1080), minute: 1092))
        XCTAssertEqual(store.state.hub.above, "Swimming ends")
        XCTAssertEqual(store.state.hub.below, "Play starts")
        await store.send(.knobReleased(0))
        XCTAssertEqual(store.state.selectedItem?.end, 1090, "snapped to 5 minutes; Play keeps its last 20")
        XCTAssertEqual(store.state.edit.blocks.first { $0.title == "Play" }?.start, 1020, "the template stays")
        // A typed end that leaves Play under 15 minutes runs on to Dinner.
        await store.send(.endPicked(tuesday.date(minute: 1100, calendar: F.calendar)))
        XCTAssertEqual(store.state.selectedItem?.end, 1110)
        await store.send(.saveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(writes.items.value.first?.dayChanges, [DayChange(day: tuesday, end: 1110)])
    }

    // MARK: Grown-up mode (boards G1, G8)

    func testUndoAndRedoStepThroughChanges() async {
        let store = await loaded()
        XCTAssertFalse(store.state.canUndo)
        XCTAssertFalse(store.state.canRedo)
        await store.send(.knobDragged(index: knob(store, at: 1155), minute: 1170))
        await store.send(.knobReleased(knob(store, at: 1170)))
        XCTAssertTrue(store.state.canUndo)
        await store.send(.undoTapped)
        XCTAssertEqual(store.state.edit.knobs.map(\.minute).contains(1155), true)
        XCTAssertTrue(store.state.canRedo)
        await store.send(.redoTapped)
        XCTAssertEqual(store.state.edit.knobs.map(\.minute).contains(1170), true)
        XCTAssertFalse(store.state.canRedo)
    }

    func testListShowsEveryWeekAndJustOnceAndOpensItems() async {
        let swim = F.weekly()
        let store = TestStore(initialState: OurDayFeature.State(kid: SeedData.kidA.id, today: tuesday, calendar: F.calendar)) {
            OurDayFeature()
        } withDependencies: {
            $0.calendar = F.calendar
            $0.date.now = self.tuesday.date(minute: 600, calendar: F.calendar)
            $0.scheduleStore.load = { ScheduleSnapshot(kids: SeedData.kids, routines: SeedData.routines, items: [swim]) }
            $0.holidays.holidays = { _ in [] }
            $0.schoolDirectory.calendar = { _, _ in .none }
        }
        store.exhaustivity = .off
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.listTapped)
        XCTAssertTrue(store.state.showsList)
        XCTAssertEqual(store.state.listSections.map(\.title), ["Every week"])
        XCTAssertEqual(store.state.listSections.first?.rows.map(\.title), ["Example Primary School", "Swimming"])
        await store.send(.listRowTapped(.item(swim.id)))
        await store.receive(\.delegate.openItem)
        await store.send(.addTapped)
        await store.receive(\.delegate.add)
        await store.send(.settingsTapped)
        await store.receive(\.delegate.openSettings)
    }

    func testListAndSettingsAskFirstWithUnsavedChanges() async {
        let store = await loaded()
        await store.send(.knobDragged(index: knob(store, at: 1155), minute: 1170))
        await store.send(.knobReleased(knob(store, at: 1170)))
        await store.send(.listTapped)
        XCTAssertTrue(store.state.isConfirmingLeave)
        XCTAssertFalse(store.state.showsList)
        await store.send(.unsavedSaveTapped)
        await store.receive(\.saved)
        XCTAssertTrue(store.state.showsList, "Save goes on to the List")
    }

    /// Views hold no values: the header, the cards' and the slice card's words come from State,
    /// through the injected localizer.
    func testTheWordsComeFromState() {
        let state = OurDayFeature.State(kid: SeedData.kidA.id, today: tuesday, calendar: F.calendar)
        XCTAssertEqual(state.scopeTabs.map(\.0), [.thisDay, .allDays])
        XCTAssertEqual([state.title, state.listTitle, state.settingsTitle, state.saveTitle, state.addTitle,
                        state.unsavedTitle, state.unsavedCancel, state.unsavedSave, state.fromWhenTitle,
                        state.fromWhenSave, state.fromWhenCancel, state.pickerTodayTitle, state.moreTitle,
                        state.newNameLabel, state.bringBackTitle] + state.scopeTabs.map(\.1),
                       ["Our day", "List", "Settings", "Save", "Add", "Save the changes?", "Cancel", "Save",
                        "Change from when?", "Save", "Cancel", "Today", "More", "Name", "Bring back",
                        "This day", "Every time"])
        XCTAssertEqual([state.canUndo, state.canRedo], [false, false], "nothing to take back or put back")
        let keys = withDependencies { $0.localizer = .keys } operation: {
            OurDayFeature.State(kid: SeedData.kidA.id, today: tuesday, calendar: F.calendar)
        }
        XCTAssertEqual([keys.title, keys.listTitle, keys.settingsTitle, keys.saveTitle, keys.addTitle,
                        keys.unsavedTitle, keys.unsavedCancel, keys.unsavedSave, keys.fromWhenTitle,
                        keys.fromWhenSave, keys.fromWhenCancel, keys.pickerTodayTitle, keys.moreTitle,
                        keys.newNameLabel, keys.bringBackTitle] + keys.scopeTabs.map(\.1),
                       ["day.title", "day.list", "day.settings", "day.save", "list.add", "day.unsaved.title",
                        "day.unsaved.cancel", "day.unsaved.save", "from_when.title", "from_when.save",
                        "from_when.cancel", "day.picker.today", "picker.more", "day.new.name", "day.bring_back",
                        "day.scope.this", "day.scope.all"])
    }
}
