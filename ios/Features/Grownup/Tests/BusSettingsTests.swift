import BusClient
import ComposableArchitecture
import Domain
import Grownup
import ScheduleStore
import SecretStore
import XCTest

/// C2 with made-up stop and bus numbers only (privacy rule).
@MainActor
final class BusSettingsTests: XCTestCase {
    private let kid = SeedData.kidA.id

    private func store(key: String? = "test-key", saved: LockIsolated<[BusPlan]> = LockIsolated([]))
        -> TestStoreOf<BusSettingsFeature> {
        let store = TestStore(initialState: BusSettingsFeature.State(kid: kid)) {
            BusSettingsFeature()
        } withDependencies: {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
            $0.calendar = calendar
            $0.date.now = Date(timeIntervalSince1970: 1_793_000_000)
            $0.scheduleStore.load = { ScheduleSnapshot(kids: SeedData.kids, routines: [], items: [], busPlans: saved.value) }
            $0.scheduleStore.saveBusPlan = { plan in saved.withValue { $0.removeAll { $0.kid == plan.kid }; $0.append(plan) } }
            $0.secrets = .inMemory(key.map { [.busKey: $0] } ?? [:])
            $0.bus.stopName = { stop, _ in stop == "00000" ? "Example Stop" : nil }
            $0.bus.arrivals = { _, _ in
                [BusArrival(service: "2", minutes: 3, type: .single), BusArrival(service: "1", minutes: 5, type: .double),
                 BusArrival(service: "1", minutes: 20, type: .double)]
            }
        }
        store.exhaustivity = .off
        return store
    }

    func testStopCodeShowsItsNameAndBusChips() async {
        let store = store()
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.stopChanged("00 000x1"))
        XCTAssertEqual(store.state.stop, "00000")
        await store.receive(\.stopLooked)
        XCTAssertEqual(store.state.stopCaption, "Example Stop")
        XCTAssertEqual(store.state.servicesAtStop, ["1", "2"])
    }

    func testPickingABusSavesThePlan() async {
        let saved = LockIsolated<[BusPlan]>([])
        let store = store(saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.stopChanged("00000"))
        await store.send(.serviceTapped("1"))
        await store.send(.walkChanged(8))
        await store.finish(timeout: .seconds(1))
        XCTAssertEqual(saved.value, [BusPlan(kid: kid, stop: "00000", services: ["1"], walk: 8)])
    }

    func testTheKeyGoesToTheSecretStoreNotState() async {
        let store = store(key: nil)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.key, .missing)
        await store.send(.keyRowTapped)
        await store.send(.keyDraftChanged(" new-key "))
        await store.send(.keySaveTapped)
        XCTAssertNil(store.state.keyDraft)
        XCTAssertEqual(store.state.key, .checking)
    }
}
