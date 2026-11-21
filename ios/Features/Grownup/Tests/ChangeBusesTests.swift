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

    private func store(saved: LockIsolated<[BusPlan]>,
                       isService: @escaping @Sendable (String) async throws -> Bool = { ["3", "4", "33A"].contains($0) })
        -> TestStoreOf<ChangeBusesFeature> {
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
            $0.bus.isService = isService
            $0.bus.arrivals = { code in
                code == "00000"
                    ? [BusArrival(service: "1", minutes: 5, type: .double), BusArrival(service: "3", minutes: 8, type: .single)]
                    : [BusArrival(service: "3", minutes: 2, type: .single), BusArrival(service: "4", minutes: 6, type: .double)]
            }
        }
        store.exhaustivity = .off
        return store
    }

    /// Spec "Several buses": a first bus from our stop, the second typed by its number, and the
    /// three times; Save adds it as one more bus and keeps the others.
    func testSavingABusThatChanges() async {
        let saved = LockIsolated([BusPlan(kid: SeedData.kidA.id, stop: "00000", services: ["1", "2"], ride: 12,
                                          rides: ["2": 18])])
        let store = store(saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.receive(\.ourStop.stopLooked)
        XCTAssertEqual(store.state.fromName, "Example Stop")
        XCTAssertEqual(store.state.firstBuses, ["1", "3"], "every bus at our stop")
        XCTAssertEqual(store.state.ride1, 12, "Ride 1 starts from the route's ride")
        XCTAssertEqual(store.state.change, 5, "Change starts at 5")
        XCTAssertFalse(store.state.canSave)
        await store.send(.firstBusTapped("3"))
        await store.send(.thenChanged("4"))
        await store.receive(\.thenChecked)
        XCTAssertEqual(store.state.ride2Caption, "on 4")
        await store.send(.changeChanged(3))
        XCTAssertTrue(store.state.canSave)
        await store.send(.saveTapped)
        await store.receive(\.delegate.finished)
        XCTAssertEqual(saved.value, [BusPlan(kid: kid, stop: "00000", services: ["1", "2"], ride: 12, rides: ["2": 18],
                                             change: BusChange(firstBus: "3", thenBus: "4", ride1: 12, change: 3,
                                                               ride2: BusPlan.defaultRide))])
    }

    /// "Then" takes digits and a letter, checked against LTA's service list; a wrong one shows why
    /// and cannot be saved. Without an answer from LTA the number is taken as typed.
    func testThenIsCheckedAgainstTheServiceList() async {
        let saved = LockIsolated([BusPlan(kid: SeedData.kidA.id, stop: "00000", services: ["1"])])
        let store = store(saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.firstBusTapped("3"))
        await store.send(.thenChanged("A3"))
        XCTAssertNil(store.state.thenBus)
        XCTAssertTrue(store.state.thenHasProblem)
        XCTAssertEqual(store.state.thenCaption, "No bus with that number")
        await store.send(.thenChanged("99"))
        await store.receive(\.thenChecked)
        XCTAssertEqual(store.state.thenIsService, false)
        XCTAssertFalse(store.state.canSave)
        await store.send(.thenChanged("33a"))
        await store.receive(\.thenChecked)
        XCTAssertEqual(store.state.thenBus, "33A")
        XCTAssertFalse(store.state.thenHasProblem)
        XCTAssertTrue(store.state.canSave)

        let offline = self.store(saved: saved, isService: { _ in throw CancellationError() })
        await offline.send(.task)
        await offline.receive(\.loaded)
        await offline.send(.firstBusTapped("3"))
        await offline.send(.thenChanged("99"))
        await offline.receive(\.thenChecked)
        XCTAssertNil(offline.state.thenIsService)
        XCTAssertTrue(offline.state.canSave)
    }

    func testClearingBothBusesRemovesTheChange() async {
        let change = BusChange(firstBus: "3", thenBus: "4")
        let saved = LockIsolated([BusPlan(kid: SeedData.kidA.id, stop: "00000", services: ["1"], change: change)])
        let store = store(saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.busChange, change)
        await store.send(.firstBusTapped("3"))
        XCTAssertNil(store.state.firstBus)
        await store.send(.thenChanged(""))
        XCTAssertTrue(store.state.canSave)
        await store.send(.saveTapped)
        await store.receive(\.delegate.finished)
        XCTAssertNil(saved.value.first?.change)
        XCTAssertEqual(saved.value.first?.services, ["1"])
    }

    func testBackAsksBeforeDroppingChanges() async {
        let saved = LockIsolated([BusPlan(kid: SeedData.kidA.id, stop: "00000", services: ["1"])])
        let store = store(saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.backTapped)
        await store.receive(\.delegate.finished)
        // With a change made, ← asks first (the C3x rule).
        await store.send(.firstBusTapped("3"))
        await store.send(.backTapped)
        XCTAssertTrue(store.state.isConfirmingLeave)
        await store.send(.leaveCancelled)
        XCTAssertFalse(store.state.isConfirmingLeave)
        await store.send(.backTapped)
        await store.send(.leaveConfirmed)
        await store.receive(\.delegate.finished)
        XCTAssertNil(saved.value.first?.change)
    }
}
