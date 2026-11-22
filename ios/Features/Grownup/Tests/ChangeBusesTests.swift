import BusClient
import ComposableArchitecture
import Domain
import Grownup
import XCTest

/// C2c with made-up stop and bus numbers only (privacy rule). It edits in memory and hands the
/// route's buses that change back by delegate (C2 and S3 save them).
@MainActor
final class ChangeBusesTests: XCTestCase {
    /// Our stop as C2 or S3 has it: its name and the buses that call there.
    private var ourStop: StopSearchFeature.State {
        var stop = StopSearchFeature.State(stop: "00000")
        stop.pickedStop = BusStop(code: "00000", name: "Example Stop", road: "Example Rd")
        stop.text = "Example Stop"
        stop.servicesAtStop = ["1", "2", "3"]
        return stop
    }

    private func store(changes: [BusChange] = [], index: Int? = nil, ride: Int = 12, stop: StopSearchFeature.State? = nil,
                       isService: @escaping @Sendable (String) async throws -> Bool = { ["3", "4", "33A"].contains($0) })
        -> TestStoreOf<ChangeBusesFeature> {
        let store = TestStore(initialState: ChangeBusesFeature.State(ourStop: stop ?? ourStop, changes: changes, index: index,
                                                                     ride: ride)) {
            ChangeBusesFeature()
        } withDependencies: {
            $0.continuousClock = ImmediateClock()
            $0.bus.stop = { code in code == "00000" ? BusStop(code: code, name: "Example Stop", road: "Example Rd") : nil }
            $0.bus.searchStops = { _ in [] }
            $0.bus.isService = isService
            $0.bus.arrivals = { _ in
                [BusArrival(service: "1", minutes: 5, type: .double), BusArrival(service: "3", minutes: 8, type: .single)]
            }
        }
        store.exhaustivity = .off
        return store
    }

    /// Spec "Several buses" (v61): first buses from our stop, the second typed by its number, and the
    /// times; Save adds it after the route's other buses that change.
    func testSavingANewBusThatChanges() async {
        let other = BusChange(firstBus: "2", thenBus: "8")
        let store = store(changes: [other])
        XCTAssertEqual(store.state.fromName, "Example Stop")
        XCTAssertEqual(store.state.pills.map(\.service), ["1", "2", "3"], "every bus at our stop")
        XCTAssertEqual(store.state.change, 5, "Change starts at 5")
        XCTAssertNil(store.state.removeTitle, "a new bus has nothing to remove")
        XCTAssertNil(store.state.head)
        XCTAssertFalse(store.state.canSave)
        await store.send(.firstBusTapped("3"))
        await store.send(.thenChanged("4"))
        await store.receive(\.thenChecked)
        XCTAssertEqual(store.state.ride2Caption, "on 4")
        XCTAssertEqual(store.state.head, .change(format: "3 %@ 4"))
        await store.send(.changeChanged(3))
        XCTAssertTrue(store.state.canSave)
        await store.send(.saveTapped)
        await store.receive(.delegate(.saved([other, BusChange(firstBuses: ["3"], thenBus: "4", rides1: ["3": 12],
                                                               change: 3, ride2: BusPlan.defaultRide)])))
    }

    /// Design 2026-11-22: a − or + at its limit takes the off look (change 0–30, rides 0–90).
    func testStepperEndsTurnOffAtTheLimits() async {
        let store = store()
        XCTAssertEqual(store.state.changeEnds, StepEnds(canLower: true, canRaise: true))
        await store.send(.changeChanged(-1))
        XCTAssertEqual(store.state.changeEnds, StepEnds(canLower: false, canRaise: true))
        await store.send(.changeChanged(31))
        XCTAssertEqual(store.state.change, 30)
        XCTAssertEqual(store.state.changeEnds, StepEnds(canLower: true, canRaise: false))
        await store.send(.ride2Changed(91))
        XCTAssertEqual(store.state.ride2Ends, StepEnds(canLower: true, canRaise: false))
        await store.send(.ride1Changed(service: nil, minutes: 0))
        XCTAssertEqual(store.state.ride1Rows.map(\.ends), [StepEnds(canLower: false, canRaise: true)])
    }

    /// v61: First bus picks any number of the stop's buses, in pill order, each with its own Ride 1
    /// row ("on 1", "on 3"), the label "Ride 1" on the first only.
    func testSeveralFirstBusesEachGetARideOne() async {
        let store = store()
        // With no first bus, one Ride 1 row sets what a new pick starts with.
        XCTAssertEqual(store.state.ride1Rows.map(\.service), [nil])
        XCTAssertEqual(store.state.ride1Rows.map(\.label), ["Ride 1"])
        await store.send(.ride1Changed(service: nil, minutes: 9))
        await store.send(.firstBusTapped("3"))
        await store.send(.firstBusTapped("1"))
        XCTAssertEqual(store.state.firstBuses, ["1", "3"], "pill order")
        XCTAssertEqual(store.state.pills.map(\.isOn), [true, false, true])
        XCTAssertEqual(store.state.ride1Rows.map(\.label), ["Ride 1", ""])
        XCTAssertEqual(store.state.ride1Rows.map(\.caption), ["on 1", "on 3"])
        XCTAssertEqual(store.state.ride1Rows.map(\.minutes), [9, 9], "a new pick starts with the Ride 1 set before")
        await store.send(.ride1Changed(service: "3", minutes: 14))
        XCTAssertEqual(store.state.head, .buses("1 · 3"), "the first buses until Then is set")
        await store.send(.thenChanged("33a"))
        await store.receive(\.thenChecked)
        XCTAssertEqual(store.state.head, .change(format: "1 · 3 %@ 33A"))
        XCTAssertEqual(store.state.busChange, BusChange(firstBuses: ["1", "3"], thenBus: "33A", rides1: ["1": 9, "3": 14]))
        // Taking a first bus off drops its row and its Ride 1.
        await store.send(.firstBusTapped("1"))
        XCTAssertEqual(store.state.ride1Rows.map(\.caption), ["on 3"])
        XCTAssertEqual(store.state.ride1Rows.map(\.label), ["Ride 1"])
        XCTAssertEqual(store.state.busChange?.rides1, ["3": 14])
    }

    /// Editing a bus that exists starts from it; Save puts it back in its place.
    func testEditingABusThatChangesReplacesIt() async {
        let first = BusChange(firstBuses: ["1", "3"], thenBus: "4", rides1: ["1": 6, "3": 8], change: 4, ride2: 7)
        let second = BusChange(firstBus: "2", thenBus: "8")
        let store = store(changes: [first, second], index: 0)
        XCTAssertEqual(store.state.original, first)
        XCTAssertEqual(store.state.firstBuses, ["1", "3"])
        XCTAssertEqual(store.state.ride1Rows.map(\.minutes), [6, 8])
        XCTAssertEqual(store.state.thenText, "4")
        XCTAssertEqual(store.state.busChange, first)
        XCTAssertFalse(store.state.hasChanges)
        XCTAssertEqual(store.state.removeTitle, "Remove this bus")
        await store.send(.ride2Changed(9))
        XCTAssertTrue(store.state.hasChanges)
        await store.send(.saveTapped)
        var edited = first
        edited.ride2 = 9
        await store.receive(.delegate(.saved([edited, second])))
    }

    /// v61: "Remove this bus" asks with the shared ConfirmCard "Remove 1 · 3 → 4?" (the arrow drawn);
    /// Keep closes it, Remove hands back the list without that bus.
    func testRemoveAsksFirst() async {
        let first = BusChange(firstBuses: ["1", "3"], thenBus: "4")
        let second = BusChange(firstBus: "2", thenBus: "8")
        let store = store(changes: [first, second], index: 0)
        await store.send(.removeTapped)
        XCTAssertEqual(store.state.confirm, .remove)
        XCTAssertEqual(store.state.confirmWords?.title, "Remove 1 · 3 %@ 4?")
        XCTAssertEqual(store.state.confirmWords?.titleGlyph, .arrowRight)
        XCTAssertEqual(store.state.confirmWords?.accept, "Remove")
        XCTAssertEqual(store.state.confirmWords?.cancel, "Keep")
        XCTAssertFalse(store.state.confirmPointsAtBack)
        await store.send(.confirmCancelled)
        XCTAssertNil(store.state.confirm)
        await store.send(.removeTapped)
        await store.send(.confirmAccepted)
        await store.receive(.delegate(.saved([second])))
    }

    /// "Then" takes digits and a letter, checked against LTA's service list; a wrong one shows why
    /// and cannot be saved. Without an answer from LTA the number is taken as typed.
    func testThenIsCheckedAgainstTheServiceList() async {
        let store = store()
        await store.send(.firstBusTapped("3"))
        await store.send(.thenChanged("A3"))
        XCTAssertNil(store.state.thenBus)
        XCTAssertTrue(store.state.thenHasProblem)
        XCTAssertEqual(store.state.thenCaption, "No bus with that number")
        await store.send(.thenChanged("3"))
        XCTAssertNil(store.state.thenBus, "a first bus cannot be the second one")
        await store.send(.thenChanged("99"))
        await store.receive(\.thenChecked)
        XCTAssertEqual(store.state.thenIsService, false)
        XCTAssertFalse(store.state.canSave)
        await store.send(.thenChanged("33a"))
        await store.receive(\.thenChecked)
        XCTAssertEqual(store.state.thenBus, "33A")
        XCTAssertFalse(store.state.thenHasProblem)
        XCTAssertTrue(store.state.canSave)

        let offline = self.store(isService: { _ in throw CancellationError() })
        await offline.send(.firstBusTapped("3"))
        await offline.send(.thenChanged("99"))
        await offline.receive(\.thenChecked)
        XCTAssertNil(offline.state.thenIsService)
        XCTAssertTrue(offline.state.canSave)
    }

    func testBackAsksBeforeDroppingChanges() async {
        let store = store()
        await store.send(.backTapped)
        await store.receive(.delegate(.cancelled))
        // With a change made, ← asks first (the C3x rule).
        await store.send(.firstBusTapped("3"))
        await store.send(.backTapped)
        XCTAssertEqual(store.state.confirm, .leave)
        XCTAssertEqual(store.state.confirmWords?.title, "Leave without saving?")
        XCTAssertNil(store.state.confirmWords?.titleGlyph)
        XCTAssertTrue(store.state.confirmPointsAtBack)
        await store.send(.confirmCancelled)
        XCTAssertNil(store.state.confirm)
        await store.send(.backTapped)
        await store.send(.confirmAccepted)
        await store.receive(.delegate(.cancelled))
    }

    /// Opened before the stop's buses were known, C2c looks them up itself.
    func testItLooksUpOurStopsBusesWhenItHasNone() async {
        let store = store(stop: StopSearchFeature.State(stop: "00000"))
        XCTAssertTrue(store.state.pills.isEmpty)
        await store.send(.task)
        await store.receive(\.ourStop.stopLooked)
        XCTAssertEqual(store.state.pills.map(\.service), ["1", "3"])
        XCTAssertEqual(store.state.fromName, "Example Stop")
    }
}
