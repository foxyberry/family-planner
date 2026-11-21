import AppCore
import ComposableArchitecture
import Domain
import Grownup
import JourneyWorld
import Setup
import XCTest

/// Kids join and leave the family: G6a "Add a child" from Settings, and two kids on S1 with a remove.
@MainActor
final class FamilyJourneys: XCTestCase {
    /// G6a: no face at first, so Add stays off; a face turns it on; saved, the new kid is on the
    /// home and in Settings with the next free colour.
    func testAddingAChildPutsThemOnTheHomeAndInSettings() async throws {
        var data = WorldData.standard
        data.family = "sample"
        let world = World(data)
        var start = AppFeature.State()
        start.path.append(.settings(SettingsFeature.State(kid: SeedData.kidA.id)))
        let store = world.store(start)
        await store.send(.home(.task))
        await store.receive(\.home.loaded)
        let settings = store.state.path.ids[0]
        await store.send(.path(.element(id: settings, action: .settings(.task))))
        await store.receive(\.path[id: settings].settings.loaded)

        await store.send(.path(.element(id: settings, action: .settings(.addChildTapped))))
        await store.receive(\.path[id: settings].settings.delegate.addChild)
        let add = try XCTUnwrap(store.state.path.ids.last)
        XCTAssertEqual(addChild(store, add)?.colorIndex, 2, "the first colour no kid has")

        await store.send(.path(.element(id: add, action: .addChild(.binding(.set(\.name, "Kid C"))))))
        await store.send(.path(.element(id: add, action: .addChild(.binding(.set(\.ageText, "6"))))))
        XCTAssertEqual(addChild(store, add)?.canSave, false, "no face yet")
        await store.send(.path(.element(id: add, action: .addChild(.faceTapped("kidBoy")))))
        XCTAssertEqual(addChild(store, add)?.canSave, true)
        await store.send(.path(.element(id: add, action: .addChild(.saveTapped))))
        await store.receive(\.path[id: add].addChild.saved)
        await store.receive(\.path[id: add].addChild.delegate.finished)

        XCTAssertEqual(store.state.path.count, 1, "back on Settings")
        XCTAssertEqual(world.family.value.kids.map(\.name), ["Kid A", "Kid B", "Kid C"], "saved in the store")
        // Settings and the home both load the family again (in either order): let both finish and
        // apply what they sent.
        await store.finish()
        await store.skipReceivedActions()
        XCTAssertEqual(store.state.home.days.map(\.kid.name), ["Kid A", "Kid B", "Kid C"])
        guard case let .settings(after)? = store.state.path[id: settings] else { return XCTFail("Settings closed") }
        XCTAssertEqual(after.snapshot?.kids.map(\.name), ["Kid A", "Kid B", "Kid C"])
        XCTAssertFalse(world.family.value.missions.filter { $0.kid == after.snapshot?.kids.last?.id }.isEmpty,
                       "the new kid starts with the starter missions")
    }

    /// S1 with two kids: an empty card goes at once; a card with a name asks first, and Keep keeps it.
    func testTwoKidsOnS1AndARemove() async throws {
        let world = World()
        let store = world.store()
        await store.send(.checkFamily)
        await store.receive(\.familyChecked)
        let first = try XCTUnwrap(store.state.setup?.kids.first?.id)
        await store.send(.setup(.nameChanged(first, "Kid A")))
        await store.send(.setup(.ageChanged(first, "8")))
        await store.send(.setup(.faceTapped(first, "kidGirl")))

        // An empty second card is removed at once.
        await store.send(.setup(.addKidTapped))
        let empty = try XCTUnwrap(store.state.setup?.kids.last?.id)
        await store.send(.setup(.removeKidTapped(empty)))
        XCTAssertEqual(store.state.setup?.kids.count, 1)

        // A named one asks first: Keep keeps it, Remove removes it.
        await store.send(.setup(.addKidTapped))
        let second = try XCTUnwrap(store.state.setup?.kids.last?.id)
        await store.send(.setup(.nameChanged(second, "Kid B")))
        await store.send(.setup(.removeKidTapped(second)))
        XCTAssertNotNil(store.state.setup?.removeConfirm, "the confirm card hangs under the ×")
        await store.send(.setup(.removeCancelled))
        XCTAssertEqual(store.state.setup?.kids.count, 2)
        await store.send(.setup(.removeKidTapped(second)))
        await store.send(.setup(.removeConfirmed))
        XCTAssertEqual(store.state.setup?.kids.map(\.name), ["Kid A"])
        XCTAssertEqual(store.state.setup?.canGoNext, true)
    }

    private func addChild(_ store: TestStoreOf<AppFeature>, _ id: StackElementID) -> AddChildFeature.State? {
        guard case let .addChild(state)? = store.state.path[id: id] else { return nil }
        return state
    }
}
