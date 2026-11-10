import AppSettings
import ComposableArchitecture
import Domain
import Foundation
import Grownup
import ParentAuthClient
import ScheduleStore
import SchoolDirectory
import XCTest

/// The List's rows (board G8).
final class ItemListTests: XCTestCase {
    private typealias F = Fixture

    func testWeeklyRowsText() {
        let rows = ItemList.weekly(kid: SeedData.kidA, items: [
            F.weekly(), F.weekly("Reading", days: Weekday.schoolDays, start: 960, end: 1000),
        ])
        XCTAssertEqual(rows.map(\.when), ["Mon · Wed", "Every school day"])
        XCTAssertEqual(rows.map(\.time), ["3:30–4:30 pm", "4:00–4:40 pm"])
    }

    func testEndedSeriesAndOtherKidsItemsAreNotListed() {
        XCTAssertEqual(ItemList.weekly(kid: SeedData.kidA, items: [F.weekly(until: F.monday)]), [])
        XCTAssertEqual(ItemList.weekly(kid: SeedData.kidB, items: [F.weekly()]), [])
    }

    func testOnceRowsNearestFirstMaxFiveUntilNextWakeUp() {
        let yesterday = Day(year: 2026, month: 11, day: 8)
        let items = (0..<7).map { F.once("Event \($0)", on: F.monday.adding(days: 6 - $0, calendar: F.calendar)) }
            + [F.once("Last night", on: yesterday), F.once("Last week", on: Day(year: 2026, month: 11, day: 1))]
        // 6:00 am on Monday: Kid A wakes at 6:30, so last night's event is still listed.
        let early = ItemList.once(kid: SeedData.kidA, items: items, routines: SeedData.routines, today: F.monday,
                                  nowMinute: 360, calendar: F.calendar)
        XCTAssertEqual(early.map(\.title), ["Last night", "Event 6", "Event 5", "Event 4", "Event 3"])
        XCTAssertEqual(early.first?.when, "Sun 8 Nov")
        let later = ItemList.once(kid: SeedData.kidA, items: items, routines: SeedData.routines, today: F.monday,
                                  nowMinute: 390, calendar: F.calendar)
        XCTAssertEqual(later.first?.title, "Event 6", "gone at wake-up")
    }
}

/// Settings (board G6).
@MainActor
final class SettingsTests: XCTestCase {
    private typealias F = Fixture
    private let term4 = SchoolCalendar.Term(name: "Term 4", start: Day(year: 2026, month: 9, day: 14),
                                            end: Day(year: 2026, month: 11, day: 20))

    private func store(saved: LockIsolated<[AppSettings]> = .init([]),
                       auth: ParentAuthOutcome = .success) -> TestStoreOf<SettingsFeature> {
        let snapshot = F.snapshot(items: [])
        let store = TestStore(initialState: SettingsFeature.State()) {
            SettingsFeature()
        } withDependencies: {
            $0.calendar = F.calendar
            $0.date.now = F.monday.date(minute: 600, calendar: F.calendar)
            $0.scheduleStore.load = { snapshot }
            $0.schoolDirectory.calendar = { _, _ in SchoolCalendar(terms: [self.term4], isMoe: true) }
            $0.appSettings.load = { .defaults }
            $0.appSettings.save = { settings in saved.withValue { $0.append(settings) } }
            $0.parentAuth.authenticate = { _ in auth }
        }
        store.exhaustivity = .off
        return store
    }

    func testKidTabSectionsForASchoolKid() async {
        let store = store()
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.tab, .kid(SeedData.kidA.id))
        XCTAssertEqual(store.state.sections.map(\.title), ["About", "School", "Getting there", "Routines"])
        let rows = store.state.sections.flatMap(\.rows)
        XCTAssertEqual(rows.map(\.key), ["Age", "Face, colour", "School", "Hours", "Terms", "To school", "Missions"])
        XCTAssertEqual(rows.first { $0.key == "Face, colour" }?.value, "Blue")
        XCTAssertEqual(rows.first { $0.key == "Hours" }?.value, "Mon–Fri · 7:30 am – 3:00 pm")
        XCTAssertEqual(rows.first { $0.key == "Terms" }?.value, "MOE 2026 · Term 4 ends 20 Nov")
        XCTAssertEqual(rows.first { $0.key == "To school" }?.link, .buses)
        XCTAssertEqual(rows.first { $0.key == "Missions" }?.link, .missions)
    }

    func testAKidAtHomeHasAboutAndRoutines() async {
        let store = store()
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.tabTapped(.kid(SeedData.kidB.id)))
        XCTAssertEqual(store.state.sections.map(\.title), ["About", "Routines"])
        XCTAssertEqual(store.state.tabs.map(\.0), [.kid(SeedData.kidA.id), .kid(SeedData.kidB.id), .family])
    }

    func testFamilyTabSwitchesSaveAtOnceAndTheLockChecksFaceID() async {
        let saved = LockIsolated<[AppSettings]>([])
        let store = store(saved: saved, auth: .notAvailable)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.tabTapped(.family))
        XCTAssertEqual(store.state.settingRows.map(\.isOn), [true, true, true])
        await store.send(.settingTapped(.medals))
        XCTAssertEqual(saved.value.last?.medals, false)
        await store.send(.settingTapped(.grownupLock))
        XCTAssertEqual(saved.value.last?.grownupLock, false, "off at once")
        await store.receive(\.delegate.grownupLockChanged, false)
        await store.send(.settingTapped(.grownupLock))
        await store.receive(\.lockChecked)
        XCTAssertFalse(store.state.settings.grownupLock, "no Face ID: the lock stays off")
        XCTAssertEqual(store.state.settingRows.first?.caption, "Set up Face ID in iPad Settings first.")
    }

    func testOpensOnTheKidItWasGiven() async {
        let store = TestStore(initialState: SettingsFeature.State(kid: SeedData.kidB.id)) { SettingsFeature() }
        XCTAssertEqual(store.state.selectedKid, SeedData.kidB.id)
    }
}
