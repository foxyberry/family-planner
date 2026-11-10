import ComposableArchitecture
import Domain
import Foundation
import Grownup
import HolidayProvider
import ScheduleStore
import SchoolDirectory
import XCTest

/// Board E5: skip just one date, stop the series, or change it from the next time on.
@MainActor
final class WeeklyEditTests: XCTestCase {
    private typealias F = Fixture
    private let swim = F.weekly()   // Kid A, Mon · Wed 3:30–4:30

    private func store(_ item: ScheduleItem? = nil, minute: Int = 600, on day: Day = F.monday,
                       saved: LockIsolated<[[ScheduleItem]]> = .init([])) -> TestStoreOf<ItemEditorFeature> {
        let item = item ?? swim
        let now = day.date(minute: minute, calendar: F.calendar)
        let snapshot = F.snapshot(items: [item])
        let store = TestStore(initialState: ItemEditorFeature.State(mode: .editWeekly(item), now: now,
                                                                    calendar: F.calendar)) {
            ItemEditorFeature()
        } withDependencies: {
            $0.calendar = F.calendar
            $0.date.now = now
            $0.uuid = .incrementing
            $0.scheduleStore.load = { snapshot }
            $0.scheduleStore.save = { item in saved.withValue { $0.append([item]) } }
            $0.scheduleStore.saveAll = { items in saved.withValue { $0.append(items) } }
            $0.holidays.holidays = { _ in [] }
            $0.schoolDirectory.calendar = { _, _ in .none }
        }
        store.exhaustivity = .off
        return store
    }

    func testSkipSavesAtOnceAndOffersUndo() async {
        let saved = LockIsolated<[[ScheduleItem]]>([])
        let store = store(saved: saved)
        XCTAssertEqual(store.state.skipRowTitle, "Skip just Mon 9 Nov")
        XCTAssertFalse(store.state.skipRowIsUndo)
        await store.send(.skipRowTapped)
        await store.receive(\.skipSaved)
        XCTAssertEqual(store.state.skipRowTitle, "Skipped Mon 9 Nov · Undo")
        XCTAssertTrue(store.state.skipRowIsUndo)
        XCTAssertEqual(saved.value.last?.first?.skippedDays, [F.monday])
        XCTAssertFalse(store.state.hasChanges, "skipping is saved on its own, not a form change")
    }

    func testUndoRemovesException() async {
        let saved = LockIsolated<[[ScheduleItem]]>([])
        let store = store(saved: saved)
        await store.send(.skipRowTapped)
        await store.receive(\.skipSaved)
        await store.send(.skipRowTapped)
        await store.receive(\.skipSaved)
        XCTAssertEqual(saved.value.last?.first?.skippedDays, [])
        XCTAssertEqual(store.state.skipRowTitle, "Skip just Mon 9 Nov")
        XCTAssertFalse(store.state.skipRowIsUndo)
    }

    func testSkipOffersDateAfterAlreadySkipped() {
        var skipped = swim
        skipped.skippedDays = [F.monday]
        let store = store(skipped)
        XCTAssertEqual(store.state.skipRowTitle, "Skip just Wed 11 Nov")
    }

    func testRemoveAsksThenEndsSeriesAndFinishes() async {
        let saved = LockIsolated<[[ScheduleItem]]>([])
        let store = store(saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.removeSeriesTapped)
        XCTAssertEqual(store.state.confirmTitle, "Remove Swimming every week?")
        XCTAssertEqual(store.state.confirmMessage,
                       "It leaves Kid A's clock from Mon 9 Nov. Days before stay in the diary.")
        await store.send(.confirmAccepted)
        await store.receive(\.saved)
        await store.receive(\.delegate.finished)
        XCTAssertEqual(saved.value.last?.first?.recurrence,
                       .weekly([.monday, .wednesday], from: Day(year: 2026, month: 11, day: 1),
                               until: Day(year: 2026, month: 11, day: 8)))
    }

    func testSaveChangesSplitsWhenRunningToday() async {
        let saved = LockIsolated<[[ScheduleItem]]>([])
        let store = store(minute: 945, saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.binding(.set(\.form.end, 1020)))
        await store.send(.saveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(saved.value.last?.count, 2)
        XCTAssertEqual(saved.value.last?.first?.end, 990, "today keeps the old times")
        XCTAssertEqual(saved.value.last?.last?.end, 1020)
    }

    func testSaveChangesInPlaceOtherwise() async {
        let saved = LockIsolated<[[ScheduleItem]]>([])
        let store = store(on: Day(year: 2026, month: 11, day: 10), saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.binding(.set(\.form.end, 1020)))
        await store.send(.saveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(saved.value.last?.count, 1)
        XCTAssertEqual(saved.value.last?.first?.id, swim.id)
        XCTAssertEqual(saved.value.last?.first?.end, 1020)
    }

    func testSideColumnTitleAndNoPreview() {
        let store = store()
        XCTAssertTrue(store.state.isEditingWeekly)
        XCTAssertEqual(store.state.everyTitle, "Every Mon and Wed")
        XCTAssertNil(store.state.preview, "the every-week side column shows no preview")
    }

    func testRepeatCannotSwitchToJustOnce() async {
        let store = store()
        await store.send(.repeatChanged(.once))
        XCTAssertEqual(store.state.form.repeats, .weekly)
    }
}
