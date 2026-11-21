import AppCore
import ComposableArchitecture
import Domain
import Grownup
import Home
import JourneyWorld
import XCTest

/// Our day (board G1, spec C6 "One card for everything on the clock"): a grown-up adds and removes
/// things on the clock; after Save the kid's home clock shows it.
@MainActor
final class OurDayJourneys: XCTestCase {
    /// The "+" between Dinner and Shower adds a just-once item for today; Save puts it on Kid A's
    /// home clock. Its slice card's "Remove" asks first ("Remove Piano?"), and the next Save takes
    /// it off the home clock again.
    func testAnItemAddedOnTheClockShowsOnTheHomeUntilRemoved() async throws {
        var data = WorldData.standard
        data.family = "sample"
        let world = World(data)
        let store = world.store()
        await store.send(.home(.task))
        await store.receive(\.home.loaded)

        // The pencil, Face ID, then Our day on today's clock.
        await store.send(.home(.pencilTapped))
        await store.receive(\.parentAuthResponse)
        let ourDay = try XCTUnwrap(store.state.path.ids.first)
        await store.send(.path(.element(id: ourDay, action: .ourDay(.task))))
        await store.receive(\.path[id: ourDay].ourDay.loaded)

        let plus = try XCTUnwrap(day(store, ourDay)?.addButtons.first { $0.minute == 1155 }, "a + between Dinner and Shower")
        await store.send(.path(.element(id: ourDay, action: .ourDay(.addBetweenTapped(plus.knob)))))
        XCTAssertEqual(day(store, ourDay)?.hub.above, "New")
        await store.send(.path(.element(id: ourDay, action: .ourDay(.newSlicePicturePicked("actPiano")))))
        XCTAssertEqual(day(store, ourDay)?.selectedTitle, "Piano")
        await store.send(.path(.element(id: ourDay, action: .ourDay(.saveTapped))))
        await store.receive(\.path[id: ourDay].ourDay.saved)
        await store.receive(\.home.loaded)

        let piano = try XCTUnwrap(world.family.value.items.first { $0.title == "Piano" })
        XCTAssertEqual(piano.recurrence, .once(world.today), "This day: just once")
        XCTAssertEqual(world.family.value.routines, SeedData.routines, "the day template did not change")
        XCTAssertEqual(kidA(store)?.slots.first { $0.title == "Piano" }?.start, 1155, "on the home clock")

        // The same slice card: just once, so one Remove (no scope tabs), with a confirm first.
        XCTAssertEqual(day(store, ourDay)?.showsScopeTabs, false)
        XCTAssertEqual(day(store, ourDay)?.sliceActionTitle, "Remove")
        await store.send(.path(.element(id: ourDay, action: .ourDay(.sliceActionTapped))))
        XCTAssertEqual(day(store, ourDay)?.removeTitle, "Remove Piano?")
        await store.send(.path(.element(id: ourDay, action: .ourDay(.removeConfirmed))))
        XCTAssertEqual(day(store, ourDay)?.selectedTitle, "Shower", "the slice underneath is picked")
        XCTAssertNotNil(kidA(store)?.slots.first { $0.title == "Piano" }, "nothing changes before Save")
        await store.send(.path(.element(id: ourDay, action: .ourDay(.saveTapped))))
        await store.receive(\.path[id: ourDay].ourDay.saved)
        await store.receive(\.home.loaded)
        XCTAssertFalse(world.family.value.items.contains { $0.title == "Piano" })
        XCTAssertNil(kidA(store)?.slots.first { $0.title == "Piano" })
    }

    /// School's "Remove" on All days opens G7 with "At home" picked (spec C6, e39b24d); Save from
    /// today makes Kid A a kid at home, and Our day shows the day without School.
    func testSchoolRemoveGoesThroughG7AtHome() async throws {
        var data = WorldData.standard
        data.family = "sample"
        let world = World(data)
        let store = world.store()
        await store.send(.home(.task))
        await store.receive(\.home.loaded)
        await store.send(.home(.pencilTapped))
        await store.receive(\.parentAuthResponse)
        let ourDay = try XCTUnwrap(store.state.path.ids.first)
        await store.send(.path(.element(id: ourDay, action: .ourDay(.task))))
        await store.receive(\.path[id: ourDay].ourDay.loaded)

        let school = try XCTUnwrap(day(store, ourDay)?.edit.blocks.first { $0.kind == .school })
        await store.send(.path(.element(id: ourDay, action: .ourDay(.sliceTapped(start: school.start)))))
        await store.send(.path(.element(id: ourDay, action: .ourDay(.scopeTapped(.allDays)))))
        await store.send(.path(.element(id: ourDay, action: .ourDay(.sliceActionTapped))))
        await store.receive(\.path[id: ourDay].ourDay.delegate.removeSchool)
        let g7 = try XCTUnwrap(store.state.path.ids.last)
        guard case .changeSchool? = store.state.path[id: g7] else { return XCTFail("G7 is not open") }
        await store.send(.path(.element(id: g7, action: .changeSchool(.task))))
        await store.receive(\.path[id: g7].changeSchool.loaded)
        guard case let .changeSchool(change)? = store.state.path[id: g7], case let .ready(form) = change.phase
        else { return XCTFail("G7 did not load") }
        XCTAssertEqual(form.place, .home, "At home is picked")
        XCTAssertTrue(form.isShowingStartsOn)

        await store.send(.path(.element(id: g7, action: .changeSchool(.datePicked(world.now)))))
        await store.send(.path(.element(id: g7, action: .changeSchool(.saveTapped))))
        await store.receive(\.path[id: g7].changeSchool.saved)
        await store.receive(\.path[id: g7].changeSchool.delegate.finished)
        await store.receive(\.path[id: ourDay].ourDay.loaded)
        XCTAssertNil(world.family.value.kids.first { $0.id == SeedData.kidA.id }?.school, "the school record changed")
        XCTAssertEqual(store.state.path.ids.last, ourDay, "back on Our day")
        XCTAssertFalse(day(store, ourDay)?.edit.blocks.contains { $0.kind == .school } ?? true)
    }

    private func day(_ store: TestStoreOf<AppFeature>, _ id: StackElementID) -> OurDayFeature.State? {
        guard case let .ourDay(day)? = store.state.path[id: id] else { return nil }
        return day
    }

    private func kidA(_ store: TestStoreOf<AppFeature>) -> HomeFeature.KidDay? {
        store.state.home.days.first { $0.kid.id == SeedData.kidA.id }
    }
}
