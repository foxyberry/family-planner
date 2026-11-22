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

    /// Spec "Several buses" (v61): each bus that changes is one more pill ("12 · 34 → 33"); a tap opens
    /// its C2c, the link (always there) opens a new one, and what C2c hands back is saved.
    func testEveryBusThatChangesIsOneMorePill() async {
        let first = BusChange(firstBuses: ["1", "2"], thenBus: "4")
        let second = BusChange(firstBus: "2", thenBus: "5")
        let saved = LockIsolated([BusPlan(kid: SeedData.kidA.id, stop: "00000", services: ["1"], changes: [first, second])])
        let store = store(saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.receive(\.search.stopLooked)
        XCTAssertEqual(store.state.changes, [first, second])
        XCTAssertEqual(store.state.changePills.map(\.title), ["1 · 2", "2"])
        XCTAssertEqual(store.state.changePills.map(\.then), ["4", "5"])
        XCTAssertEqual(store.state.changeLink, "A bus that changes…", "the link shows with buses that change too")
        await store.send(.changeTapped(1))
        await store.receive(.delegate(.openChange(index: 1)))
        let editor = store.state.changeEditor(index: 1)
        XCTAssertEqual(editor.original, second)
        XCTAssertEqual(editor.ourStop.servicesAtStop, ["1", "2"], "C2c gets our stop's buses")
        XCTAssertNil(store.state.changeEditor(index: nil).original)
        await store.send(.changeLinkTapped)
        await store.receive(.delegate(.openChange(index: nil)))
        // C2c saved: the route keeps its direct bus and takes the new list.
        await store.send(.changesSaved([second]))
        await store.finish(timeout: .seconds(1))
        XCTAssertEqual(saved.value.last?.changes, [second])
        XCTAssertEqual(saved.value.last?.services, ["1"])
        // A direct 2 sits next to the bus that changes from 2; both stay.
        await store.send(.serviceTapped("2"))
        await store.finish(timeout: .seconds(1))
        XCTAssertEqual(saved.value.last?.changes, [second])
        XCTAssertEqual(saved.value.last?.services, ["1", "2"])
    }

    /// Review of #159: removing the route's only bus (a bus that changes) is saved, so it stays gone
    /// when C2 opens again; taking off the last direct bus sticks the same way.
    func testRemovingTheOnlyBusSticks() async {
        let only = BusChange(firstBus: "2", thenBus: "5")
        let saved = LockIsolated([BusPlan(kid: SeedData.kidA.id, stop: "00000", services: [], changes: [only])])
        let store = store(saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.changesSaved([]))
        await store.finish(timeout: .seconds(1))
        XCTAssertEqual(saved.value.last?.changes, [], "the empty route is saved")
        XCTAssertEqual(saved.value.last?.stop, "00000", "the stop stays")

        let reopened = self.store(saved: saved)
        await reopened.send(.task)
        await reopened.receive(\.loaded)
        XCTAssertEqual(reopened.state.changes, [], "it stays gone")
        await reopened.send(.serviceTapped("1"))
        await reopened.send(.serviceTapped("1"))
        await reopened.finish(timeout: .seconds(1))
        XCTAssertEqual(saved.value.last?.services, [], "taking off the last bus sticks too")
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
        XCTAssertEqual(store.state.changeLink, "A bus that changes…")
        // Spec "Several buses": with no bus picked, one Ride row sets the ride a new pick starts with.
        XCTAssertEqual(store.state.rideRows.map(\.service), [nil])
        XCTAssertEqual(store.state.rideRows.first?.caption, "stop to school")
        await store.send(.rideChanged(service: nil, minutes: 12))
        await store.send(.serviceTapped("2"))
        await store.send(.serviceTapped("1"))
        XCTAssertEqual(store.state.services, ["1", "2"], "pill order")
        XCTAssertEqual(store.state.rideRows.map(\.label), ["Ride", ""])
        XCTAssertEqual(store.state.rideRows.map(\.caption), ["on 1", "on 2"])
        await store.send(.rideChanged(service: "2", minutes: 18))
        await store.finish(timeout: .seconds(1))
        XCTAssertEqual(saved.value.last?.services, ["1", "2"])
        XCTAssertEqual(saved.value.last?.ride(on: "1"), 12, "a new pick starts with the ride set before")
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
        // Closing the list after a pick keeps the stop and its buses (S3, 2026-11-21).
        await store.send(.search(.listClosed))
        XCTAssertEqual(store.state.search.servicesAtStop, ["1", "2"])
        XCTAssertEqual(store.state.search.stop, "00000")
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

    /// Back from C2c the screen appears again: it keeps what it has (the stop's buses and what C2c
    /// handed back) and reads nothing older over it (user, 2026-11-21).
    func testComingBackKeepsWhatC2Has() async {
        let saved = LockIsolated([BusPlan(kid: SeedData.kidA.id, stop: "00000", services: ["1"])])
        let store = store(saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.receive(\.search.stopLooked)
        XCTAssertEqual(store.state.search.servicesAtStop, ["1", "2"])
        let change = BusChange(firstBus: "2", thenBus: "4")
        await store.send(.changesSaved([change]))
        await store.send(.task)
        await store.finish(timeout: .seconds(1))
        XCTAssertEqual(store.state.changes, [change], "not read back from an older copy")
        XCTAssertEqual(store.state.search.servicesAtStop, ["1", "2"])
        XCTAssertEqual(store.state.search.text, "Example Stop")
        XCTAssertEqual(saved.value.last?.changes, [change])
    }

    /// "Late" is the school's Latest − Arrive by (spec "Latest lives on the school record").
    /// Design 2026-11-22: a − or + at its limit takes the off look (walk 0–60, ride 0–90, grace 0–30).
    func testStepperEndsTurnOffAtTheLimits() async {
        let store = store()
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.walkChanged(-1))
        XCTAssertEqual(store.state.walk, 0)
        XCTAssertEqual(store.state.walkEnds, StepEnds(canLower: false, canRaise: true))
        await store.send(.walkChanged(61))
        XCTAssertEqual(store.state.walk, 60)
        XCTAssertEqual(store.state.walkEnds, StepEnds(canLower: true, canRaise: false))
        await store.send(.rideChanged(service: nil, minutes: 0))
        XCTAssertEqual(store.state.rideRows.map(\.ends), [StepEnds(canLower: false, canRaise: true)])
        await store.send(.graceChanged(35))
        XCTAssertEqual(store.state.lateGrace, 30)
        XCTAssertEqual(store.state.graceEnds, StepEnds(canLower: true, canRaise: false))
        await store.finish(timeout: .seconds(1))
    }

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
