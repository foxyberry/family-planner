import ComposableArchitecture
import Domain
import Foundation
import Grownup
import ScheduleStore
import XCTest

/// C6 · Our day: dragging, limits, locked school edges, free time, undo, leaving and saving.
@MainActor
final class OurDayTests: XCTestCase {
    private typealias F = Fixture
    private let tuesday = Day(year: 2026, month: 11, day: 10)

    private func store(saved: LockIsolated<[Routine]> = .init([])) -> TestStoreOf<OurDayFeature> {
        let store = TestStore(initialState: OurDayFeature.State(kid: SeedData.kidA.id, today: tuesday,
                                                                calendar: F.calendar)) {
            OurDayFeature()
        } withDependencies: {
            $0.calendar = F.calendar
            $0.scheduleStore.load = { ScheduleSnapshot(kids: SeedData.kids, routines: SeedData.routines, items: []) }
            $0.scheduleStore.saveRoutine = { routine in saved.withValue { $0.append(routine) } }
        }
        store.exhaustivity = .off
        return store
    }

    private func loaded(saved: LockIsolated<[Routine]> = .init([])) async -> TestStoreOf<OurDayFeature> {
        let store = store(saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        return store
    }

    private func knob(_ store: TestStoreOf<OurDayFeature>, at minute: Int) -> Int {
        store.state.edit.knobs.firstIndex { $0.minute == minute }!
    }

    func testLoadsTheKidsWeekdayTemplate() async {
        let store = await loaded()
        XCTAssertEqual(store.state.edit.knobs.map(\.minute), [390, 450, 900, 960, 1020, 1110, 1155, 1200])
        XCTAssertEqual(store.state.knobs[knob(store, at: 1155)].label, "Dinner ends, 7:15 pm")
    }

    func testDraggingADinnerKnobShowsTheTimeAndTheEffect() async {
        let store = await loaded()
        let index = knob(store, at: 1155)
        await store.send(.knobDragged(index: index, minute: 1168))
        XCTAssertEqual(store.state.hub.time, "7:30 pm")
        XCTAssertEqual(store.state.hub.above, "Dinner ends")
        XCTAssertEqual(store.state.hub.below, "Shower starts")
        XCTAssertEqual(store.state.dragOrigin, 1155)
        XCTAssertEqual(store.state.message, "Shower now starts at 7:30 pm and is 30 min.")
        XCTAssertEqual(store.state.haptics.steps, 1, "one 5-minute step, not on the hour")
        await store.send(.knobReleased(index))
        XCTAssertNil(store.state.dragging)
        XCTAssertEqual(store.state.selectedBlock?.title, "Dinner")
    }

    func testLimitsBumpAndLockedEdgesExplain() async {
        let store = await loaded()
        await store.send(.knobDragged(index: knob(store, at: 1155), minute: 1250))
        XCTAssertEqual(store.state.edit.blocks.first { $0.title == "Shower" }?.start, 1185)
        XCTAssertGreaterThan(store.state.haptics.bumps, 0)
        await store.send(.lockedKnobTapped(knob(store, at: 450)))
        XCTAssertEqual(store.state.message, "School hours are set in School.")
    }

    func testFreeTimeThenFillThenUndo() async {
        let store = await loaded()
        let play = store.state.edit.blocks.first { $0.title == "Play" }!
        await store.send(.sliceTapped(start: play.start))
        XCTAssertTrue(store.state.canMakeFree)
        await store.send(.makeFreeTapped)
        XCTAssertEqual(store.state.selectedBlock?.kind, .free)
        await store.send(.plusTapped(start: play.start))
        XCTAssertNotNil(store.state.newSlice)
        await store.send(.binding(.set(\.newSlice, .init(block: store.state.newSlice!.block, name: "Piano",
                                                          iconName: "actPiano"))))
        await store.send(.newSliceAddTapped)
        XCTAssertEqual(store.state.selectedBlock?.title, "Piano")
        await store.send(.undoTapped)
        await store.send(.undoTapped)
        XCTAssertEqual(store.state.edit.blocks.first { $0.start == play.start }?.title, "Play")
        XCTAssertFalse(store.state.edit.isChanged)
    }

    func testLeavingWithChangesAsksFirst() async {
        let store = await loaded()
        await store.send(.knobDragged(index: knob(store, at: 1155), minute: 1170))
        await store.send(.backTapped)
        XCTAssertTrue(store.state.isConfirmingLeave)
        await store.send(.leaveConfirmed)
        await store.receive(\.delegate.finished)
    }

    func testSwitchingDayTypeWithoutChangesLoadsItsTemplate() async {
        let store = await loaded()
        await store.send(.dayTypeTapped(.sunday))
        XCTAssertTrue(store.state.showsHolidayNote)
        XCTAssertEqual(store.state.edit.blocks.first?.end, 450, "the weekend shape wakes at 7:30 am")
    }

    func testSaveStartsTomorrow() async {
        let saved = LockIsolated<[Routine]>([])
        let store = await loaded(saved: saved)
        await store.send(.knobDragged(index: knob(store, at: 1155), minute: 1170))
        await store.send(.knobReleased(knob(store, at: 1170)))
        await store.send(.saveTapped)
        await store.receive(\.saved)
        await store.receive(\.delegate.finished)
        XCTAssertEqual(saved.value.first?.from, Day(year: 2026, month: 11, day: 11))
        XCTAssertEqual(saved.value.first?.blocks.first { $0.title == "Dinner" }?.end, 1170)
    }
}
