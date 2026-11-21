import AppCore
import ComposableArchitecture
import Domain
import JourneyWorld
import Setup
import XCTest

/// First-run setup S1 → S4 on an empty iPad, through the root store, until the home shows the kid.
@MainActor
final class FirstRunJourneys: XCTestCase {
    /// One kid with a school who takes the bus. Two round trips the iPad showed (2026-11-21) are
    /// replayed as actions: a text field sends its text again when the keyboard goes away, and that
    /// must not undo a pick (S2's school, S3's stop).
    func testOneKidFromAnEmptyIPadToTheHome() async throws {
        let world = World()
        let store = world.store()

        // An empty store opens S1.
        await store.send(.checkFamily)
        await store.receive(\.familyChecked)
        XCTAssertEqual(store.state.setup?.step, .family)
        await store.send(.setup(.task))
        await store.receive(\.setup.directoryLoaded)

        // S1: Kid A, 8, a face. Next needs all three.
        let kid = try XCTUnwrap(store.state.setup?.kids.first?.id)
        await store.send(.setup(.nameChanged(kid, "Kid A")))
        await store.send(.setup(.ageChanged(kid, "8")))
        XCTAssertEqual(store.state.setup?.canGoNext, false, "no face yet")
        await store.send(.setup(.faceTapped(kid, "kidGirl")))
        XCTAssertEqual(store.state.setup?.canGoNext, true)
        await store.send(.setup(.nextTapped))
        XCTAssertEqual(store.state.setup?.step, .school)

        // S2: type, pick the school; the field resends its text as the keyboard closes.
        await store.send(.setup(.schoolTextChanged("exam")))
        await store.send(.setup(.schoolPicked(try XCTUnwrap(world.school("example-primary")))))
        let typed = store.state.setup?.tabKid?.school.text ?? ""
        await store.send(.setup(.schoolTextChanged(typed)))
        XCTAssertEqual(store.state.setup?.tabKid?.school.picked?.id, "example-primary", "the pick stays")
        XCTAssertEqual(store.state.setup?.canGoNext, true, "default times count without touching a wheel")
        await store.send(.setup(.nextTapped))
        XCTAssertEqual(store.state.setup?.step, .gettingThere)

        // S3: by bus from stop 12345; the field resends "12345" when the keyboard closes.
        await store.send(.setup(.wayPicked(.bus)))
        await store.send(.setup(.stopSearch(.textChanged("12345"))))
        await store.receive(\.setup.stopSearch.stopLooked)
        XCTAssertEqual(store.state.setup?.goingSearch.servicesAtStop, ["1", "2"])
        await store.send(.setup(.stopSearch(.textChanged("12345"))))
        XCTAssertEqual(store.state.setup?.goingSearch.stop, "12345", "one pick is enough")
        XCTAssertEqual(store.state.setup?.goingSearch.servicesAtStop, ["1", "2"], "the stop's buses stay")
        await store.send(.setup(.serviceTapped("1")))
        await store.send(.setup(.walkChanged(8)))
        XCTAssertEqual(store.state.setup?.canGoNext, true)
        await store.send(.setup(.nextTapped))
        XCTAssertEqual(store.state.setup?.step, .almostDone)

        // S4: Start saves the family once and opens the home.
        XCTAssertTrue(world.family.value.kids.isEmpty, "nothing is saved before Start")
        await store.send(.setup(.nextTapped))
        await store.receive(\.setup.saved)
        await store.receive(\.setup.delegate.finished)
        XCTAssertNil(store.state.setup)
        XCTAssertEqual(store.state.hasFamily, true)
        XCTAssertEqual(world.family.value.kids.map(\.name), ["Kid A"])
        XCTAssertEqual(world.family.value.busPlans.map(\.services), [["1"]])

        // The home appears and shows Kid A's day.
        await store.send(.home(.task))
        await store.receive(\.home.reload)
        await store.receive(\.home.loaded)
        XCTAssertEqual(store.state.home.days.map(\.kid.name), ["Kid A"])
        XCTAssertEqual(store.state.home.today, world.today)
    }
}
