import BusClient
import ComposableArchitecture
import Domain
import Grownup
import ScheduleStore
import XCTest

/// C2c with made-up stop and bus numbers only (privacy rule).
@MainActor
final class ChangeBusesTests: XCTestCase {
    private let kid = SeedData.kidA.id

    private func store(saved: LockIsolated<[BusPlan]>) -> TestStoreOf<ChangeBusesFeature> {
        let store = TestStore(initialState: ChangeBusesFeature.State(kid: kid)) {
            ChangeBusesFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
            $0.scheduleStore.load = {
                ScheduleSnapshot(kids: SeedData.kids, routines: [], items: [], busPlans: saved.value)
            }
            $0.scheduleStore.saveBusPlan = { plan in saved.withValue { $0.removeAll { $0.kid == plan.kid }; $0.append(plan) } }
            $0.bus.stop = { code in
                switch code {
                case "00000": BusStop(code: code, name: "Example Stop", road: "Example Rd")
                case "00001": BusStop(code: code, name: "Example Int", road: "Example Ave")
                default: nil
                }
            }
            $0.bus.searchStops = { _ in [] }
            $0.bus.arrivals = { code in
                code == "00000"
                    ? [BusArrival(service: "1", minutes: 5, type: .double), BusArrival(service: "3", minutes: 8, type: .single)]
                    : [BusArrival(service: "3", minutes: 2, type: .single), BusArrival(service: "4", minutes: 6, type: .double)]
            }
        }
        store.exhaustivity = .off
        return store
    }

    func testSavingAChangeReplacesTheDirectSecond() async {
        let saved = LockIsolated([BusPlan(kid: SeedData.kidA.id, stop: "00000", services: ["1", "2"], ride: 12, secondRide: 18)])
        let store = store(saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.receive(\.ourStop.stopLooked)
        XCTAssertEqual(store.state.fromName, "Example Stop")
        XCTAssertEqual(store.state.firstBuses, ["3"], "the kid's 1st is not offered")
        XCTAssertEqual(store.state.ride1, 12, "Ride 1 starts from the 1st's ride")
        XCTAssertFalse(store.state.canSave)
        await store.send(.firstBusTapped("3"))
        await store.send(.search(.textChanged("00001")))
        await store.receive(\.search.stopLooked)
        XCTAssertEqual(store.state.thenBuses, ["4"], "the bus the kid gets off is not offered")
        await store.send(.thenBusTapped("4"))
        await store.send(.walkChanged(3))
        XCTAssertEqual(store.state.ride2Caption, "on 4")
        XCTAssertTrue(store.state.canSave)
        await store.send(.saveTapped)
        await store.receive(\.delegate.finished)
        XCTAssertEqual(saved.value, [BusPlan(kid: kid, stop: "00000", services: ["1"], ride: 12,
                                             change: BusChange(firstBus: "3", stop: "00001", thenBus: "4", ride1: 12,
                                                               walk: 3, ride2: BusPlan.defaultRide))])
    }

    func testClearingBothBusesRemovesTheChange() async {
        let change = BusChange(firstBus: "3", stop: "00001", thenBus: "4")
        let saved = LockIsolated([BusPlan(kid: SeedData.kidA.id, stop: "00000", services: ["1"], change: change)])
        let store = store(saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.change, change)
        await store.send(.firstBusTapped("3"))
        XCTAssertNil(store.state.firstBus)
        XCTAssertEqual(store.state.thenBus, "4")
        await store.send(.thenBusTapped("4"))
        XCTAssertTrue(store.state.canSave)
        await store.send(.saveTapped)
        await store.receive(\.delegate.finished)
        XCTAssertNil(saved.value.first?.change)
    }

    func testBackLeavesWithoutSaving() async {
        let saved = LockIsolated([BusPlan(kid: SeedData.kidA.id, stop: "00000", services: ["1"])])
        let store = store(saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.firstBusTapped("3"))
        await store.send(.backTapped)
        await store.receive(\.delegate.finished)
        XCTAssertNil(saved.value.first?.change)
    }
}
