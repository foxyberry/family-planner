import AppCore
import ComposableArchitecture
import Domain
import Grownup
import XCTest

/// The grown-up lock (board C0): hold the clock 2 s, then Face ID, then Our day; after 2 minutes
/// without a touch the grown-up screens close again. The hold itself is a UI test; here it arrives
/// as the home's `clockHoldCompleted`.
@MainActor
final class LockJourneys: XCTestCase {
    /// The home with the sample family loaded, as a kid sees it.
    private func home(_ data: WorldData) async -> (World, TestStoreOf<AppFeature>) {
        var data = data
        data.family = "sample"
        let world = World(data)
        let store = world.store()
        await store.send(.home(.task))
        await store.receive(\.home.reload)
        await store.receive(\.home.loaded)
        return (world, store)
    }

    /// Face ID doesn't know the face, then "Try again" and it does: Our day opens on the first kid.
    func testAFaceIDRetryOpensOurDay() async {
        var data = WorldData.standard
        data.faceID = "notRecognised"
        let (world, store) = await home(data)

        await store.send(.home(.clockHoldCompleted))
        XCTAssertEqual(store.state.lock, .scanning)
        await store.receive(\.parentAuthResponse)
        XCTAssertEqual(store.state.lock, .notRecognised)
        XCTAssertNotNil(store.state.lockCard?.primary, "a second try is offered")
        XCTAssertTrue(store.state.path.isEmpty)

        world.auth.setValue(.success)
        await store.send(.lockPrimaryTapped)
        await store.receive(\.parentAuthResponse)
        XCTAssertNil(store.state.lock)
        XCTAssertEqual(store.state.path.count, 1)
        guard case let .ourDay(ourDay)? = store.state.path.first else { return XCTFail("Our day is not open") }
        XCTAssertEqual(ourDay.kid, SeedData.kidA.id)
    }

    /// Cancelling Face ID leaves the kid on the home: nothing grown-up opens.
    func testCancellingFaceIDStaysHome() async {
        var data = WorldData.standard
        data.faceID = "cancelled"
        let (_, store) = await home(data)
        await store.send(.home(.clockHoldCompleted))
        await store.receive(\.parentAuthResponse)
        XCTAssertNil(store.state.lock)
        XCTAssertTrue(store.state.path.isEmpty)
    }

    /// An iPad without Face ID set up: the hold was the gate, so "Enter" opens Our day.
    func testWithoutFaceIDTheHoldIsTheGate() async {
        var data = WorldData.standard
        data.faceID = "notAvailable"
        let (_, store) = await home(data)
        await store.send(.home(.clockHoldCompleted))
        await store.receive(\.parentAuthResponse)
        XCTAssertNotNil(store.state.lockCard?.primary, "the Enter button")
        await store.send(.lockPrimaryTapped)
        XCTAssertNil(store.state.lock)
        XCTAssertEqual(store.state.path.count, 1)
    }

    /// Two minutes without a touch close the grown-up screens; the last 30 seconds count down.
    func testTwoIdleMinutesCloseTheGrownupScreens() async {
        let (world, store) = await home(.standard)
        await store.send(.home(.clockHoldCompleted))
        await store.receive(\.parentAuthResponse)
        XCTAssertEqual(store.state.path.count, 1)

        for _ in 0..<90 { await store.send(.tick(world.now)) }
        XCTAssertNotNil(store.state.relockCaption, "the countdown shows from 90 s")
        XCTAssertEqual(store.state.path.count, 1)
        for _ in 0..<30 { await store.send(.tick(world.now)) }
        XCTAssertTrue(store.state.path.isEmpty, "back on the home after 120 s")
        XCTAssertNil(store.state.relockCaption)
    }
}
