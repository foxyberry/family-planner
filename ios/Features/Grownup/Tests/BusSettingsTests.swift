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
            $0.continuousClock = ImmediateClock()
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
        XCTAssertEqual(saved.value, [BusPlan(kid: kid, stop: "00000", services: ["1"], walk: 8, rides: ["1": 10])])
    }

    /// Spec "Several buses": the bus that changes is one more pill; the link shows until there is
    /// one, and both open C2c.
    func testABusThatChangesIsOneMorePill() async {
        let change = BusChange(firstBus: "2", thenBus: "4")
        let saved = LockIsolated([BusPlan(kid: SeedData.kidA.id, stop: "00000", services: ["1"], change: change)])
        let store = store(saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.receive(\.search.stopLooked)
        XCTAssertEqual(store.state.change, change)
        XCTAssertFalse(store.state.showsChangeLink)
        await store.send(.changeLinkTapped)
        await store.receive(\.delegate.openChange)
        // A direct 2 sits next to the bus that changes; both stay.
        await store.send(.serviceTapped("2"))
        await store.finish(timeout: .seconds(1))
        XCTAssertEqual(saved.value.last?.change, change)
        XCTAssertEqual(saved.value.last?.services, ["1", "2"])
    }

    /// Spec "Several buses": pills toggle on their own, in pill order, each with its own Ride row
    /// ("Ride" on the first only).
    func testEveryBusGetsItsOwnRide() async {
        let saved = LockIsolated<[BusPlan]>([])
        let store = store(saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.search(.textChanged("00000")))
        await store.receive(\.search.stopLooked)
        XCTAssertTrue(store.state.showsChangeLink)
        XCTAssertEqual(store.state.changeLink, "A bus that changes…")
        await store.send(.serviceTapped("2"))
        await store.send(.serviceTapped("1"))
        XCTAssertEqual(store.state.services, ["1", "2"], "pill order")
        XCTAssertEqual(store.state.rideRows.map(\.label), ["Ride", ""])
        XCTAssertEqual(store.state.rideRows.map(\.caption), ["on 1", "on 2"])
        XCTAssertEqual(store.state.rideRows.map(\.spoken), ["Ride on 1", "Ride on 2"])
        await store.send(.rideChanged(service: "2", minutes: 18))
        await store.finish(timeout: .seconds(1))
        XCTAssertEqual(saved.value.last?.services, ["1", "2"])
        XCTAssertEqual(saved.value.last?.ride(on: "1"), 10)
        XCTAssertEqual(saved.value.last?.ride(on: "2"), 18)
        await store.send(.serviceTapped("1"))
        await store.finish(timeout: .seconds(1))
        XCTAssertEqual(saved.value.last?.services, ["2"])
        XCTAssertEqual(saved.value.last?.rides, ["2": 18], "a bus taken off keeps no ride")
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
        await store.send(.search(.textChanged("examp")))
        await store.receive(\.search.stopsFound, timeout: .seconds(2))
        await store.send(.search(.stopPicked(store.state.search.matches[0])))
        XCTAssertEqual(store.state.search.stop, "00000")
        XCTAssertEqual(store.state.search.text, "Example Stop")
        XCTAssertEqual(store.state.search.caption, "Example Rd · 00000")
        await store.receive(\.search.stopLooked)
        XCTAssertEqual(store.state.search.servicesAtStop, ["1", "2"])
    }

    /// User review 2026-11-14: focusing the field or typing does not touch the picked stop or its
    /// buses; only picking a stop (or a full 5-digit code) changes them.
    func testTheBusesStayUntilANewStopIsPicked() async {
        let kid = self.kid
        let saved = LockIsolated([BusPlan(kid: SeedData.kidA.id, stop: "00000", services: ["1"])])
        let store = store(saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.receive(\.search.stopLooked)
        XCTAssertEqual(store.state.search.text, "Example Stop")
        // A tap on the field sends the same text: nothing changes, no search starts.
        await store.send(.search(.textChanged("Example Stop")))
        XCTAssertEqual(store.state.search.matches, [])
        XCTAssertEqual(store.state.search.servicesAtStop, ["1", "2"])
        // Typing a new name searches, but the stop and its buses stay until a pick.
        await store.send(.search(.textChanged("exam")))
        await store.receive(\.search.stopsFound)
        XCTAssertEqual(store.state.search.stop, "00000")
        XCTAssertEqual(store.state.search.servicesAtStop, ["1", "2"])
        XCTAssertNotNil(store.state.plan)
        // Part of a code keeps them too.
        await store.send(.search(.textChanged("123")))
        XCTAssertEqual(store.state.search.stop, "00000")
        XCTAssertEqual(store.state.search.servicesAtStop, ["1", "2"])
    }

    /// "Late" is the school's Latest − Arrive by (spec "Latest lives on the school record").
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
