import AppCore
import ComposableArchitecture
import Domain
import Missions
import XCTest

/// The morning: the kids' home and A2 · Morning missions, by the clock.
@MainActor
final class MorningJourneys: XCTestCase {
    /// The time machine moves the app clock past midnight: the home turns to the next day and
    /// loads it again, without a relaunch.
    func testANewDayReloadsTheHome() async throws {
        var data = WorldData.standard
        data.family = "sample"
        let world = World(data)
        let store = world.store()
        await store.send(.home(.task))
        await store.receive(\.home.loaded)
        XCTAssertEqual(store.state.home.weekday, .tuesday)

        let wednesday = world.calendar.date(byAdding: .day, value: 1, to: world.now)!
        await store.send(.home(.tick(wednesday)))
        await store.receive(\.home.reload)
        await store.receive(\.home.loaded)
        XCTAssertEqual(store.state.home.today, Day(wednesday, calendar: world.calendar))
        XCTAssertEqual(store.state.home.weekday, .wednesday)
        XCTAssertEqual(store.state.home.days.map(\.kid.name), ["Kid A", "Kid B"])

        // Another tick on the same day doesn't load it again.
        let loads = world.loads.value
        await store.send(.home(.tick(wednesday.addingTimeInterval(1))))
        await store.finish()
        XCTAssertEqual(world.loads.value, loads, "no second load on the same day")
        XCTAssertEqual(store.state.home.today, Day(wednesday, calendar: world.calendar))
    }

    /// Board A3 (spec, PR 155): after the slide the done view stays. No kid comes up by itself,
    /// however long the screen waits; a row tap chooses the other kid, and the ready kid's row
    /// shows its done view again.
    func testTheDoneViewStaysUntilAKidRowIsTapped() async throws {
        var data = WorldData.standard
        data.family = "sample"
        let world = World(data)
        let store = world.store()
        await store.send(.home(.task))
        await store.receive(\.home.loaded)
        await store.send(.home(.missionsTapped))
        let morning = try XCTUnwrap(store.state.path.ids.first)
        await store.send(.path(.element(id: morning, action: .missions(.task))))
        await store.receive(\.path[id: morning].missions.loaded)
        let kidA = SeedData.kidA.id, kidB = SeedData.kidB.id
        XCTAssertEqual(missions(store, morning)?.chosen, kidA)

        await store.send(.path(.element(id: morning, action: .missions(.slid))))
        XCTAssertNotNil(missions(store, morning)?.done, "Kid A's done view")
        XCTAssertTrue(world.slides.value.contains { $0.kid == kidA && $0.ready }, "the slide is saved")

        // The app still moves to the next kid after 3 s; the spec says it stays. Expected to fail
        // until the main session's fix lands: then XCTest reports the expectation as unmet, and
        // this wrapper comes off.
        await world.clock.advance(by: .seconds(10))
        await store.skipReceivedActions()
        XCTExpectFailure("A3: the app still picks the next kid 3 s after the slide (spec PR 155)") {
            XCTAssertEqual(missions(store, morning)?.chosen, kidA, "no kid switches by itself")
            XCTAssertNotNil(missions(store, morning)?.done, "the done view stays")
        }

        // A row tap chooses the other kid; tapping the ready kid's row shows the done view again.
        await store.send(.path(.element(id: morning, action: .missions(.kidTapped(kidB)))))
        XCTAssertEqual(missions(store, morning)?.chosen, kidB)
        XCTAssertNil(missions(store, morning)?.done, "Kid B isn't ready yet")
        await store.send(.path(.element(id: morning, action: .missions(.kidTapped(kidA)))))
        XCTAssertEqual(missions(store, morning)?.chosen, kidA)
        XCTAssertNotNil(missions(store, morning)?.done, "Kid A's done view again")

        await store.skipInFlightEffects()  // A2's clock and live-times timers
    }

    private func missions(_ store: TestStoreOf<AppFeature>, _ id: StackElementID) -> MissionsFeature.State? {
        guard case let .missions(state)? = store.state.path[id: id] else { return nil }
        return state
    }
}
