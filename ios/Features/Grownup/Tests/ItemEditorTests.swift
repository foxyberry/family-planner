import ComposableArchitecture
import Domain
import Foundation
import Grownup
import HolidayProvider
import ScheduleStore
import XCTest

@MainActor
final class ItemEditorTests: XCTestCase {
    private typealias F = Fixture
    private let kidA = Audience.kid(SeedData.kidA.id)

    private func store(mode: ItemEditorFeature.Mode, repeats: ItemForm.Repeat = .weekly, items: [ScheduleItem] = [],
                       saved: LockIsolated<[ScheduleItem]> = .init([]), deleted: LockIsolated<[UUID]> = .init([]),
                       saveError: Bool = false) -> TestStoreOf<ItemEditorFeature> {
        let now = F.monday.date(minute: 600, calendar: F.calendar)
        let snapshot = F.snapshot(items: items)
        let store = TestStore(initialState: ItemEditorFeature.State(mode: mode, repeats: repeats, now: now,
                                                                    calendar: F.calendar)) {
            ItemEditorFeature()
        } withDependencies: {
            $0.calendar = F.calendar
            $0.date.now = now
            $0.uuid = .incrementing
            $0.scheduleStore.load = { snapshot }
            $0.scheduleStore.save = { item in
                if saveError { throw CocoaError(.fileWriteUnknown) }
                saved.withValue { $0.append(item) }
            }
            $0.scheduleStore.delete = { id in deleted.withValue { $0.append(id) } }
            $0.holidays.holidays = { _ in [] }
        }
        store.exhaustivity = .off
        return store
    }

    private func fill(_ store: TestStoreOf<ItemEditorFeature>) async {
        await store.send(.picturePicked("actArt"))
        await store.send(.binding(.set(\.form.start, 930)))
        await store.send(.binding(.set(\.form.end, 990)))
    }

    func testAddWeeklySavesAndFinishes() async {
        let saved = LockIsolated<[ScheduleItem]>([])
        let store = store(mode: .add(kidA), saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await fill(store)
        XCTAssertEqual(store.state.form.name, "Art")
        await store.send(.saveTapped)
        await store.receive(\.saved)
        await store.receive(\.delegate.finished)
        XCTAssertEqual(saved.value.map(\.title), ["Art"])
        XCTAssertEqual(saved.value.first?.recurrence, .weekly([.monday], from: F.monday, until: nil))
    }

    func testSaveIsBlockedWhileTheFormHasAProblem() async {
        let saved = LockIsolated<[ScheduleItem]>([])
        let store = store(mode: .add(kidA), saved: saved)
        XCTAssertEqual(store.state.problem?.message, "Give it a name")
        await store.send(.saveTapped)
        XCTAssertEqual(saved.value, [])
    }

    func testSwitchToJustOnceKeepsForWhatNameWhen() async {
        let store = store(mode: .add(kidA))
        await fill(store)
        await store.send(.repeatChanged(.once))
        XCTAssertEqual(store.state.form.repeats, .once)
        XCTAssertEqual(store.state.form.name, "Art")
        XCTAssertEqual(store.state.form.iconName, "actArt")
        XCTAssertEqual([store.state.form.start, store.state.form.end], [930, 990])
        XCTAssertEqual(store.state.form.audience, kidA)
    }

    func testBackWithChangesAsksLeaveWithoutAdding() async {
        let store = store(mode: .add(kidA))
        await fill(store)
        await store.send(.backTapped)
        XCTAssertEqual(store.state.confirm, .leave)
        XCTAssertEqual(store.state.confirmTitle, "Leave without adding?")
        await store.send(.confirmCancelled)
        XCTAssertNil(store.state.confirm)
        await store.send(.backTapped)
        await store.send(.confirmAccepted)
        await store.receive(\.delegate.finished)
    }

    func testBackWithoutChangesLeavesAtOnce() async {
        let store = store(mode: .add(kidA))
        await store.send(.backTapped)
        await store.receive(\.delegate.finished)
        XCTAssertNil(store.state.confirm)
    }

    func testSaveFailureKeepsFormAndShowsCaption() async {
        let store = store(mode: .add(kidA), saveError: true)
        await fill(store)
        await store.send(.saveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(store.state.saveError, "Couldn't save. Try again.")
        XCTAssertEqual(store.state.form.name, "Art")
    }

    func testDateChipsShowFiveFromTodayAndPageByWeek() async {
        let store = store(mode: .add(kidA), repeats: .once)
        XCTAssertEqual(store.state.visibleDates.first, F.monday)
        XCTAssertEqual(store.state.visibleDates.count, 5)
        await store.send(.datePageTapped(-1))
        XCTAssertEqual(store.state.visibleDates.first, F.monday, "past dates are not shown")
        await store.send(.datePageTapped(1))
        XCTAssertEqual(store.state.visibleDates.first, Day(year: 2026, month: 11, day: 16))
    }

    func testEditOnceRemoveAsksAndDeletes() async {
        let party = F.once("Party", on: Day(year: 2026, month: 11, day: 14))
        let deleted = LockIsolated<[UUID]>([])
        let store = store(mode: .editOnce(party), items: [party], deleted: deleted)
        XCTAssertEqual(store.state.title, "Edit Party")
        await store.send(.removeTapped)
        XCTAssertEqual(store.state.confirm, .removeOnce)
        XCTAssertEqual(store.state.confirmTitle, "Remove Party?")
        XCTAssertEqual(store.state.confirmMessage, "It leaves the clock on Saturday 14 Nov.")
        await store.send(.confirmAccepted)
        await store.receive(\.removed)
        await store.receive(\.delegate.finished)
        XCTAssertEqual(deleted.value, [party.id])
    }
}
