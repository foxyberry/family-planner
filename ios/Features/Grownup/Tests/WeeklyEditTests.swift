import ComposableArchitecture
import Domain
import Foundation
import Grownup
import HolidayProvider
import ScheduleStore
import SchoolDirectory
import XCTest

/// Boards E5, G2, G3, G5: This day (skip or change one day), All days (from when?), stop the series.
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

    func testThisDayIsTheDefaultAndSkipSavesAtOnce() async {
        let saved = LockIsolated<[[ScheduleItem]]>([])
        let store = store(saved: saved)
        XCTAssertTrue(store.state.isThisDay)
        XCTAssertEqual(store.state.thisDayTitle, "Mon 9 Nov only")
        XCTAssertEqual(store.state.skipTitle, "Skip this day")
        await store.send(.skipRowTapped)
        await store.receive(\.skipSaved)
        XCTAssertEqual(store.state.skipTitle, "Bring back this day")
        XCTAssertEqual(store.state.thisDayTitle, "Mon 9 Nov only", "the skipped day stays this day")
        XCTAssertEqual(saved.value.last?.first?.skippedDays, [F.monday])
        XCTAssertFalse(store.state.hasChanges, "skipping is saved on its own, not a form change")
        await store.send(.skipRowTapped)
        await store.receive(\.skipSaved)
        XCTAssertEqual(saved.value.last?.first?.skippedDays, [])
        XCTAssertEqual(store.state.skipTitle, "Skip this day")
    }

    func testThisDayIsTheNextDayNotSkipped() {
        var skipped = swim
        skipped.skippedDays = [F.monday]
        XCTAssertEqual(store(skipped).state.thisDayTitle, "Wed 11 Nov only")
    }

    func testThisDaySavesAChangeForThatDayOnly() async {
        let saved = LockIsolated<[[ScheduleItem]]>([])
        let store = store(saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.binding(.set(\.form.end, 1020)))
        await store.send(.saveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(saved.value.last?.first?.id, swim.id)
        XCTAssertEqual(saved.value.last?.first?.end, 990, "the series keeps its times")
        XCTAssertEqual(saved.value.last?.first?.dayChanges, [DayChange(day: F.monday, end: 1020)])
    }

    func testAllDaysAsksFromWhenAndSplitsTheSeries() async {
        let saved = LockIsolated<[[ScheduleItem]]>([])
        let store = store(saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.scopeTapped(.allDays))
        XCTAssertEqual(store.state.everyTitle, "Every Mon and Wed")
        await store.send(.binding(.set(\.form.end, 1020)))
        await store.send(.saveTapped)
        XCTAssertEqual(store.state.fromWhen, .today)
        XCTAssertEqual(store.state.fromWhenTabs.map(\.1), ["Today", "Next Wed", "Date"])
        await store.send(.fromWhenPicked(.next))
        XCTAssertEqual(store.state.splitDay, Day(year: 2026, month: 11, day: 11))
        await store.send(.fromWhenSaveTapped)
        await store.receive(\.saved)
        await store.receive(\.delegate.finished)
        let items = saved.value.last ?? []
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first?.recurrence, .weekly([.monday, .wednesday], from: Day(year: 2026, month: 11, day: 1),
                                                        until: Day(year: 2026, month: 11, day: 10)))
        XCTAssertEqual(items.last?.end, 1020)
        XCTAssertEqual(items.last?.recurrence, .weekly([.monday, .wednesday], from: Day(year: 2026, month: 11, day: 11),
                                                       until: nil))
    }

    func testFromWhenListsChangedDaysThatNoLongerFit() async {
        var changed = swim
        changed.dayChanges = [DayChange(day: Day(year: 2026, month: 11, day: 16), start: 960)]
        let store = store(changed)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.scopeTapped(.allDays))
        await store.send(.dayToggled(.monday))
        await store.send(.saveTapped)
        XCTAssertEqual(store.state.fromWhenCaption, "16 Nov was changed and no longer fits. It’ll be removed.")
        await store.send(.fromWhenCancelTapped)
        XCTAssertNil(store.state.fromWhen)
    }

    func testRemoveAsksThenEndsSeriesAndFinishes() async {
        let saved = LockIsolated<[[ScheduleItem]]>([])
        let store = store(saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.scopeTapped(.allDays))
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
