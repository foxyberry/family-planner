import ComposableArchitecture
import Domain
import Foundation
import Grownup
import ScheduleStore
import XCTest

/// G6f "+ Add a child": the S1 kid card for one new kid, saved with the starter days and missions.
@MainActor
final class AddChildTests: XCTestCase {
    private typealias F = Fixture

    func testAddsAKidAtHomeWithStarterDaysAndMissions() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([]), missions = LockIsolated<[Mission]>([])
        let store = TestStore(initialState: AddChildFeature.State(today: F.monday, takenColours: [0, 1])) {
            AddChildFeature()
        } withDependencies: {
            $0.uuid = .incrementing
            $0.scheduleStore.saveKid = { kid in kids.withValue { $0.append(kid) } }
            $0.scheduleStore.saveRoutine = { routine in routines.withValue { $0.append(routine) } }
            $0.scheduleStore.saveMissions = { _, list in missions.withValue { $0 += list } }
        }
        store.exhaustivity = .off
        XCTAssertEqual(store.state.colorIndex, 2, "the first colour nobody has")
        XCTAssertFalse(store.state.canSave)
        await store.send(.binding(.set(\.name, "Kid C")))
        await store.send(.binding(.set(\.ageText, "3")))
        await store.send(.faceTapped("kidBoy"))
        XCTAssertTrue(store.state.canSave)
        await store.send(.saveTapped)
        await store.receive(\.saved)
        await store.receive(\.delegate.finished)
        XCTAssertEqual(kids.value.first?.name, "Kid C")
        XCTAssertEqual(kids.value.first?.age, 3)
        XCTAssertNil(kids.value.first?.school, "a new kid starts at home")
        XCTAssertEqual(Set(routines.value.map(\.dayType)), [.weekday, .saturday, .sunday])
        XCTAssertFalse(missions.value.isEmpty)
    }

    func testAnAgeOutOfRangeCannotSave() async {
        let store = TestStore(initialState: AddChildFeature.State(today: F.monday, takenColours: [])) { AddChildFeature() }
        await store.send(.binding(.set(\.name, "Kid C"))) { $0.name = "Kid C" }
        await store.send(.binding(.set(\.ageText, "40"))) { $0.ageText = "40" }
        XCTAssertFalse(store.state.canSave)
    }
}
