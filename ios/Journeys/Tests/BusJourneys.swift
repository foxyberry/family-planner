import AppCore
import ComposableArchitecture
import Domain
import Grownup
import XCTest

/// Our buses (C2) and a bus that changes (C2c), walked through the root store.
@MainActor
final class BusJourneys: XCTestCase {
    private let kid = SeedData.kidA.id

    /// iPad finding (2026-11-21): back from C2c, C2 had lost its buses. Add a bus that changes, come
    /// back: the stop, its buses and the picked ones are all still there, and so is the change.
    func testAddingABusThatChangesKeepsOurBuses() async {
        var data = WorldData.standard
        data.family = "sample"
        data.routes = [.init(kid: "Kid A", stop: "12345", buses: ["1", "2"], walk: 8, ride: 10)]
        let world = World(data)
        var start = AppFeature.State()
        start.path.append(.busSettings(BusSettingsFeature.State(kid: kid)))
        let store = world.store(start)
        let c2 = store.state.path.ids[0]

        // C2 opens: the saved stop, the buses at it, the two we ride.
        await store.send(.path(.element(id: c2, action: .busSettings(.task))))
        await store.receive(\.path[id: c2].busSettings.loaded)
        await store.receive(\.path[id: c2].busSettings.search.stopLooked)
        XCTAssertEqual(c2State(store, c2)?.search.stop, "12345")
        XCTAssertEqual(c2State(store, c2)?.search.servicesAtStop, ["1", "2"])
        XCTAssertEqual(c2State(store, c2)?.services, ["1", "2"])

        // "+ A bus that changes…" opens C2c on top.
        await store.send(.path(.element(id: c2, action: .busSettings(.changeLinkTapped))))
        await store.receive(\.path[id: c2].busSettings.delegate.openChange)
        XCTAssertEqual(store.state.path.count, 2)
        let c2c = store.state.path.ids[1]

        // C2c (an editor in memory): first bus 2 from our stop, then 33, and save.
        await store.send(.path(.element(id: c2c, action: .changeBuses(.firstBusTapped("2")))))
        await store.send(.path(.element(id: c2c, action: .changeBuses(.thenChanged("33")))))
        await world.clock.advance(by: .seconds(1))
        await store.receive(\.path[id: c2c].changeBuses.thenChecked)
        await store.send(.path(.element(id: c2c, action: .changeBuses(.saveTapped))))
        await store.receive(\.path[id: c2c].changeBuses.delegate.saved)

        // Back on C2: it takes the buses that change and saves them; nothing it showed is gone.
        XCTAssertEqual(store.state.path.count, 1)
        await store.receive(\.path[id: c2].busSettings.changesSaved)
        XCTAssertEqual(c2State(store, c2)?.search.stop, "12345")
        XCTAssertEqual(c2State(store, c2)?.search.servicesAtStop, ["1", "2"], "the stop's buses are kept, not looked up again")
        XCTAssertEqual(c2State(store, c2)?.services, ["1", "2"], "our buses are kept")
        XCTAssertEqual(c2State(store, c2)?.changes.first?.firstBuses, ["2"])
        XCTAssertEqual(c2State(store, c2)?.changes.first?.thenBus, "33")
        await store.finish()
        XCTAssertEqual(world.family.value.busPlans.first?.services, ["1", "2"], "the store kept them too")
        XCTAssertEqual(world.family.value.busPlans.first?.changes.map(\.thenBus), ["33"])
    }

    private func c2State(_ store: TestStoreOf<AppFeature>, _ id: StackElementID) -> BusSettingsFeature.State? {
        guard case let .busSettings(state)? = store.state.path[id: id] else { return nil }
        return state
    }
}
