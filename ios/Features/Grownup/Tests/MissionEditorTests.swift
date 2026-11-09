import ComposableArchitecture
import Domain
import Foundation
import Grownup
import ScheduleStore
import XCTest

/// C5 · Morning missions: add up to 8, rename, remove (asks first), reorder; every change saves.
@MainActor
final class MissionEditorTests: XCTestCase {
    private let kidA = SeedData.kidA.id
    private let kidB = SeedData.kidB.id

    private func loaded(kid: Kid.ID? = nil,
                        saved: LockIsolated<[Mission]> = .init([])) async -> TestStoreOf<MissionEditorFeature> {
        let store = TestStore(initialState: MissionEditorFeature.State(kid: kid ?? kidA)) {
            MissionEditorFeature()
        } withDependencies: {
            $0.uuid = .incrementing
            $0.scheduleStore.load = {
                ScheduleSnapshot(kids: SeedData.kids, routines: [], items: [], missions: SeedData.missions)
            }
            $0.scheduleStore.saveMissions = { _, missions in saved.setValue(missions) }
        }
        store.exhaustivity = .off
        await store.send(.task)
        await store.receive(\.loaded)
        return store
    }

    private func id(_ suffix: String) -> Mission.ID { UUID(uuidString: "5EED0000-0000-4000-8000-000000000\(suffix)")! }

    func testListsTheKidsMissionsInOrder() async {
        let store = await loaded()
        XCTAssertEqual(store.state.rows.map(\.name),
                       ["Wake up", "Brush teeth", "Get dressed", "Breakfast", "Pack bag", "Shoes on"])
        XCTAssertEqual(store.state.caption, "Same order as Kid A’s morning screen")
        XCTAssertEqual(store.state.addTitle, "Add a mission (6 of 8)")
        XCTAssertFalse(store.state.showsCardsNote)
        await store.send(.kidTabTapped(kidB))
        XCTAssertEqual(store.state.rows.map(\.name), ["Wake up", "Milk", "Shoes"])
        XCTAssertTrue(store.state.showsCardsNote)
    }

    /// A new mission starts as a star with no name; Save stays off until it has one. At 8 the add
    /// row is gone ("8 is the most").
    func testAddsUpToEight() async {
        let saved = LockIsolated<[Mission]>([])
        let store = await loaded(saved: saved)
        await store.send(.addTapped)
        XCTAssertEqual(store.state.draft?.picture, "star")
        XCTAssertEqual(store.state.draft?.canSave, false)
        await store.send(.saveTapped)
        XCTAssertEqual(store.state.rows.count, 6)

        await store.send(.draftNameChanged("Water bottle"))
        await store.send(.saveTapped)
        XCTAssertNil(store.state.draft)
        XCTAssertEqual(store.state.rows.last?.name, "Water bottle")
        XCTAssertEqual(store.state.rows.last?.order, 6)

        await store.send(.addTapped)
        await store.send(.draftNameChanged("Hat"))
        await store.send(.saveTapped)
        XCTAssertFalse(store.state.canAdd)
        await store.send(.addTapped)
        XCTAssertNil(store.state.draft)
        await store.finish(timeout: .seconds(1))
        XCTAssertEqual(saved.value.count, 8)
    }

    func testNamesStopAtFourteenCharacters() async {
        let store = await loaded()
        await store.send(.addTapped)
        await store.send(.draftNameChanged("A very long mission name"))
        XCTAssertEqual(store.state.draft?.name, "A very long mi")
    }

    /// Renaming keeps the id, so today's tick stays.
    func testRenameKeepsTheMission() async {
        let store = await loaded()
        await store.send(.rowTapped(id("302")))
        XCTAssertEqual(store.state.draft?.name, "Brush teeth")
        XCTAssertEqual(store.state.draft?.isNew, false)
        await store.send(.draftNameChanged("Teeth"))
        await store.send(.draftPicturePicked("washFace"))
        await store.send(.saveTapped)
        let mission = store.state.rows[1]
        XCTAssertEqual(mission.id, id("302"))
        XCTAssertEqual(mission.name, "Teeth")
        XCTAssertEqual(mission.picture, "washFace")
    }

    func testRemoveAsksFirst() async {
        let store = await loaded()
        await store.send(.rowTapped(id("303")))
        await store.send(.removeTapped)
        XCTAssertEqual(store.state.removeTitle, "Remove Get dressed?")
        await store.send(.removeCancelled)
        XCTAssertNil(store.state.removeTitle)
        XCTAssertEqual(store.state.rows.count, 6)

        await store.send(.removeTapped)
        await store.send(.removeConfirmed)
        XCTAssertNil(store.state.draft)
        XCTAssertEqual(store.state.rows.map(\.order), [0, 1, 2, 3, 4])
        XCTAssertFalse(store.state.rows.contains { $0.id == self.id("303") })
    }

    func testDragReorders() async {
        let saved = LockIsolated<[Mission]>([])
        let store = await loaded(saved: saved)
        await store.send(.moved(id("306"), to: 0))
        XCTAssertEqual(store.state.rows.map(\.name).prefix(2), ["Shoes on", "Wake up"])
        XCTAssertEqual(store.state.rows.map(\.order), Array(0..<6))
        // Past the ends stays at the ends.
        await store.send(.moved(id("306"), to: -1))
        XCTAssertEqual(store.state.rows.first?.name, "Shoes on")
        await store.finish(timeout: .seconds(1))
        XCTAssertEqual(saved.value.first?.id, id("306"))
        // Kid B's missions are untouched.
        XCTAssertEqual(store.state.missions.filter { $0.kid == self.kidB }.count, 3)
    }
}
