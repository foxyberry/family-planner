import ComposableArchitecture
import Domain
import Foundation
import Grownup
import ScheduleStore
import XCTest

/// G4 · Edit School (first part), with the seed family (made-up school and times).
@MainActor
final class SchoolEditorTests: XCTestCase {
    private typealias F = Fixture
    private let tuesday = Day(year: 2026, month: 11, day: 10)

    private func store(savedKids: LockIsolated<[Kid]>, savedRoutines: LockIsolated<[Routine]>)
        -> TestStoreOf<SchoolEditorFeature> {
        var kidA = SeedData.kidA
        kidA.school?.arriveBy = 450
        kidA.school?.latest = 460
        let kids = [kidA, SeedData.kidB]
        let store = TestStore(initialState: SchoolEditorFeature.State(kid: kidA.id, today: tuesday, calendar: F.calendar)) {
            SchoolEditorFeature()
        } withDependencies: {
            $0.calendar = F.calendar
            $0.scheduleStore.load = { ScheduleSnapshot(kids: kids, routines: SeedData.routines, items: []) }
            $0.scheduleStore.saveKid = { kid in savedKids.withValue { $0.append(kid) } }
            $0.scheduleStore.saveRoutine = { routine in savedRoutines.withValue { $0.append(routine) } }
        }
        store.exhaustivity = .off
        return store
    }

    func testMovingTheStartMovesArriveByAndKeepsTheGrace() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.everyTitle, "Every school day")
        XCTAssertFalse(store.state.canSave, "nothing changed yet")
        await store.send(.startPicked(tuesday.date(minute: 480, calendar: F.calendar)))
        XCTAssertEqual(store.state.school?.start, 480)
        XCTAssertEqual(store.state.arriveBy, 480)
        XCTAssertEqual(store.state.latest, 490)
        await store.send(.endPicked(tuesday.date(minute: 870, calendar: F.calendar)))
        await store.send(.saveTapped)
        await store.receive(\.saved)
        await store.receive(\.delegate.finished)
        XCTAssertEqual(kids.value.last?.school?.start, 480)
        XCTAssertEqual(kids.value.last?.school?.end, 870)
        // The weekday template from today: School's slice on the new times, its neighbours following.
        let school = routines.value.last?.blocks.first { $0.kind == .school }
        XCTAssertEqual(routines.value.last?.from, tuesday)
        XCTAssertEqual(school?.start, 480)
        XCTAssertEqual(school?.end, 870)
    }

    func testDaysArriveByMedalAndGoing() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.dayToggled(.friday))
        XCTAssertEqual(store.state.everyTitle, "Mon · Tue · Wed · Thu")
        await store.send(.arriveByPicked(tuesday.date(minute: 440, calendar: F.calendar)))
        XCTAssertEqual(store.state.latest, 450, "Latest keeps the 10-minute grace")
        await store.send(.medalToggled)
        XCTAssertFalse(store.state.medal)
        await store.send(.goingTapped)
        await store.receive(\.delegate.openBuses)
    }
}
