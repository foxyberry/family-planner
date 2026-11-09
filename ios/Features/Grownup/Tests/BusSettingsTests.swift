import BusClient
import ComposableArchitecture
import Domain
import Grownup
import ScheduleStore
import XCTest

/// C2 with made-up stop and bus numbers only (privacy rule).
@MainActor
final class BusSettingsTests: XCTestCase {
    private let kid = SeedData.kidA.id

    private func store(saved: LockIsolated<[BusPlan]> = LockIsolated([]), kids: [Kid] = SeedData.kids,
                       savedKids: LockIsolated<[Kid]> = LockIsolated([])) -> TestStoreOf<BusSettingsFeature> {
        let store = TestStore(initialState: BusSettingsFeature.State(kid: kid)) {
            BusSettingsFeature()
        } withDependencies: {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
            $0.calendar = calendar
            $0.date.now = Date(timeIntervalSince1970: 1_793_000_000)
            $0.scheduleStore.load = { ScheduleSnapshot(kids: kids, routines: [], items: [], busPlans: saved.value) }
            $0.scheduleStore.saveKid = { kid in savedKids.withValue { $0.append(kid) } }
            $0.scheduleStore.saveBusPlan = { plan in saved.withValue { $0.removeAll { $0.kid == plan.kid }; $0.append(plan) } }
            $0.bus.stop = { code in code == "00000" ? BusStop(code: code, name: "Example Stop", road: "Example Rd") : nil }
            $0.bus.searchStops = { text in
                "example stop".contains(text.lowercased()) ? [BusStop(code: "00000", name: "Example Stop", road: "Example Rd")] : []
            }
            $0.bus.arrivals = { _ in
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
        await store.send(.search(.textChanged("00 000x1")))
        XCTAssertEqual(store.state.search.stop, "00000")
        await store.receive(\.search.stopLooked)
        XCTAssertEqual(store.state.search.caption, "Example Rd · 00000")
        XCTAssertEqual(store.state.search.text, "Example Stop", "the field shows the stop's name")
        XCTAssertEqual(store.state.search.servicesAtStop, ["1", "2"])
    }

    func testPickingABusSavesThePlan() async {
        let saved = LockIsolated<[BusPlan]>([])
        let store = store(saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.search(.textChanged("00000")))
        await store.send(.serviceTapped("1"))
        await store.send(.walkChanged(8))
        await store.finish(timeout: .seconds(1))
        XCTAssertEqual(saved.value, [BusPlan(kid: kid, stop: "00000", services: ["1"], walk: 8)])
    }

    /// Families know the stop's name (user, 2026-11-09): typing a name lists stops; picking one
    /// fills the code and its buses.
    func testStopByName() async {
        let store = store()
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.search(.textChanged("exam")))
        XCTAssertEqual(store.state.search.stop, "")
        await store.receive(\.search.stopsFound, timeout: .seconds(2))
        XCTAssertEqual(store.state.search.matches.map(\.code), ["00000"])
        XCTAssertEqual(store.state.search.caption, "Tap your stop")
        XCTAssertTrue(store.state.search.isListOpen)
        // Layout v14: a tap on the veil closes the list and keeps the typed text.
        await store.send(.search(.listClosed))
        XCTAssertFalse(store.state.search.isListOpen)
        XCTAssertEqual(store.state.search.text, "exam")
        await store.send(.search(.textChanged("exam")))
        await store.receive(\.search.stopsFound, timeout: .seconds(2))
        await store.send(.search(.stopPicked(store.state.search.matches[0])))
        XCTAssertEqual(store.state.search.stop, "00000")
        XCTAssertEqual(store.state.search.text, "Example Stop")
        XCTAssertEqual(store.state.search.caption, "Example Rd · 00000")
        await store.receive(\.search.stopLooked)
        XCTAssertEqual(store.state.search.servicesAtStop, ["1", "2"])
    }

    /// "Late up to" is the school's Latest − Arrive by (spec "Latest lives on the school record").
    func testLateUpToEditsTheSchoolsLatest() async {
        var kidA = SeedData.kidA
        kidA.school?.arriveBy = 450
        kidA.school?.latest = 460
        let savedKids = LockIsolated<[Kid]>([])
        let store = store(kids: [kidA], savedKids: savedKids)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.lateGrace, 10)
        await store.send(.graceChanged(20))
        await store.finish(timeout: .seconds(1))
        XCTAssertEqual(savedKids.value.last?.school?.latest, 470)
    }
}
