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
            $0.schoolDirectory.updated = { Day(year: 2026, month: 11, day: 9) }
            $0.appSettings.load = { .defaults }
            $0.appSettings.save = { settings in saved.withValue { $0.append(settings) } }
            $0.parentAuth.authenticate = { _ in auth }
            $0.parentAuth.biometry = { .faceID }
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
        XCTAssertEqual(rows.map(\.key), ["Age", "Face", "School", "Hours", "Terms", "To school", "Missions"])
        XCTAssertEqual(rows.first { $0.key == "Face" }?.value, "Blue")
        XCTAssertEqual(rows.first { $0.key == "Hours" }?.value, "Mon–Fri · 7:30 am – 3:00 pm")
        XCTAssertEqual(rows.first { $0.key == "Terms" }?.value, "MOE 2026 · Term 4 ends 20 Nov")
        XCTAssertEqual(rows.first { $0.key == "To school" }?.link, .buses)
        XCTAssertEqual(rows.first { $0.key == "Missions" }?.link, .missions)
        // Board G6: School, Hours and Terms open G4.
        XCTAssertEqual(rows.filter { $0.link == .school }.map(\.key), ["School", "Hours", "Terms"])
    }

    /// Boards G4/G6/G7 (v57): "Bus 12 · 34 · leave 7:05" (arrive by 7:25, the fastest ride 10, walk 10);
    /// a bus that changes is named by its first bus.
    func testToSchoolNamesEveryBusAndTheLeaveTime() {
        var kid = SeedData.kidA
        kid.school?.arriveBy = 445
        let plan = BusPlan(kid: kid.id, stop: "00000", services: ["12", "34"], walk: 10, ride: 10, rides: ["34": 20],
                           changes: [BusChange(firstBus: "56", thenBus: "78")])
        let rows = SettingsModel.sections(kid: kid, missions: [], busPlan: plan, schoolYear: .none,
                                          today: Day(year: 2026, month: 11, day: 10), calendar: Fixture.calendar)
            .flatMap(\.rows)
        XCTAssertEqual(rows.first { $0.key == "To school" }?.value, "Bus 12 · 34 · 56 · leave 7:05")
    }

    /// v61: every bus that changes is named by its first buses, each number once, in pill order; the
    /// leave time uses the fastest trip (34 → 33 via Ride 1 3 + Change 2 + Ride 2 3 = 8, walk 10).
    func testToSchoolNamesEveryFirstBusOnceAndLeavesForTheFastest() {
        var kid = SeedData.kidA
        kid.school?.arriveBy = 445
        let plan = BusPlan(kid: kid.id, stop: "00000", services: ["12", "34"], walk: 10, ride: 10,
                           changes: [BusChange(firstBuses: ["34", "56"], thenBus: "33", rides1: ["34": 3, "56": 9],
                                               change: 2, ride2: 3),
                                     BusChange(firstBus: "97", thenBus: "56")])
        XCTAssertEqual(SettingsModel.toSchool(plan, school: kid.school!), "Bus 12 · 34 · 56 · 97 · leave 7:07")
    }

    /// An iPad with Touch ID names it on the lock row.
    func testTouchIDIsNamedOnTheLockRow() async {
        let store = store()
        store.dependencies.parentAuth.biometry = { .touchID }
        await store.send(.task)
        XCTAssertEqual(store.state.settingRows.first?.caption, "Touch ID before grown-up screens")
    }

    /// G6 "To school" for a kid who walks: the way and when to leave, not "Not set yet".
    func testToSchoolNamesAWalk() {
        let school = School(name: "Example Primary School", days: Weekday.schoolDays, start: 450, end: 810)
        let line = SettingsModel.going(trip: Trip(way: .walk, leaveBefore: 10), plan: nil, school: school)
        XCTAssertEqual(line.text, "Walk · leave 7:20")
        XCTAssertEqual(line.picture, "shoe")
        XCTAssertEqual(SettingsModel.going(trip: nil, plan: nil, school: school).text, "Not set yet")
    }

    /// Spec G5 "What Settings shows meanwhile": Hours shows today's hours and, while a change waits,
    /// "From {d Mon}" with the new hours under it, which opens G4 on the waiting change.
    func testTheHoursRowShowsTodaysHoursAndTheWaitingChange() {
        var later = SeedData.kidA.school!
        later.start = 510
        later.end = 840
        let today = Day(year: 2026, month: 11, day: 10)
        let kid = SeedData.kidA.savingSchool(later, from: Day(year: 2026, month: 11, day: 18), today: today)
        let rows = SettingsModel.sections(kid: kid, missions: [], busPlan: nil, schoolYear: .none, today: today,
                                          calendar: Fixture.calendar)[1].rows
        XCTAssertEqual(rows.map(\.key), ["School", "Hours", "From 18 Nov"])
        XCTAssertEqual(rows[1].value, "Mon–Fri · 7:30 am – 3:00 pm", "today's hours")
        XCTAssertEqual(rows[2].value, "Mon–Fri · 8:30 am – 2:00 pm")
        XCTAssertEqual(rows[2].link, .waitingHours)
        let none = SettingsModel.sections(kid: SeedData.kidA, missions: [], busPlan: nil, schoolYear: .none,
                                          today: today, calendar: Fixture.calendar)[1].rows
        XCTAssertEqual(none.map(\.key), ["School", "Hours"], "nothing waits")
    }

    /// Board G6 foot: "School lists · 9 Nov" over Data sources.
    func testTheFootNamesTheListsDay() async {
        let store = store()
        await store.send(.task)
        await store.receive(\.listsLoaded)
        XCTAssertEqual(store.state.listsLine, "School lists · 9 Nov")
    }

    func testAKidAtHomeHasASchoolRowToAddAPlace() async {
        let store = store()
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.tabTapped(.kid(SeedData.kidB.id)))
        // Spec "Where the kid goes changes": adding a place later starts from the School row (G7).
        XCTAssertEqual(store.state.sections.map(\.title), ["About", "School", "Routines"])
        XCTAssertEqual(store.state.sections[1].rows.map(\.value), ["At home"])
        XCTAssertEqual(store.state.sections[1].rows.first?.link, .changeSchool)
        XCTAssertEqual(store.state.tabs.map(\.0), [.kid(SeedData.kidA.id), .kid(SeedData.kidB.id), .family])
    }

    func testFamilyTabSwitchesSaveAtOnceAndTheLockChecksFaceID() async {
        let saved = LockIsolated<[AppSettings]>([])
        let store = store(saved: saved, auth: .notAvailable)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.tabTapped(.family))
        XCTAssertEqual(store.state.settingRows.map(\.isOn), [true, true])
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
