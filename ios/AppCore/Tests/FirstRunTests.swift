import AppCore
import ComposableArchitecture
import Domain
import ParentAuthClient
import ScheduleStore
import Setup
import XCTest

/// The app starts empty and runs first-run setup (user, 2026-11-09).
@MainActor
final class FirstRunTests: XCTestCase {
    private func store(kids: [Kid], auth: ParentAuthOutcome = .success) -> TestStoreOf<AppFeature> {
        let store = TestStore(initialState: AppFeature.State()) { AppFeature() } withDependencies: {
            $0.scheduleStore.load = { ScheduleSnapshot(kids: kids, routines: [], items: []) }
            $0.uuid = .incrementing
            $0.parentAuth.authenticate = { _ in auth }
            $0.date.now = Date(timeIntervalSince1970: 1_800_000_000)
            $0.calendar = Calendar(identifier: .gregorian)
        }
        store.exhaustivity = .off
        return store
    }

    func testAnEmptyStoreOpensSetupAtTheFirstStep() async {
        let store = store(kids: [])
        await store.send(.checkFamily)
        await store.receive(\.familyChecked)
        XCTAssertEqual(store.state.hasFamily, false)
        XCTAssertEqual(store.state.setup?.step, .family)
    }

    func testAFamilyOpensTheHome() async {
        let store = store(kids: SeedData.kids)
        await store.send(.checkFamily)
        await store.receive(\.familyChecked)
        XCTAssertEqual(store.state.hasFamily, true)
        XCTAssertNil(store.state.setup)
    }

    func testAStoreThatCannotBeReadNeverOpensSetup() async {
        let store = TestStore(initialState: AppFeature.State()) { AppFeature() } withDependencies: {
            $0.scheduleStore.load = { throw CancellationError() }
        }
        await store.send(.checkFamily)
        await store.finish()
        XCTAssertNil(store.state.setup)
        XCTAssertNil(store.state.hasFamily)
    }

    func testStartOpensTheHomeAndReloadsIt() async {
        let store = store(kids: [])
        await store.send(.checkFamily)
        await store.receive(\.familyChecked)
        await store.send(.setup(.delegate(.finished)))
        XCTAssertNil(store.state.setup)
        XCTAssertEqual(store.state.hasFamily, true)
        await store.receive(\.home.reload)
    }

    func testSetupLinksNameTheSteps() {
        XCTAssertEqual(ScreenLink(url: URL(string: "familyplanner://s1")!), .setup(1))
        XCTAssertEqual(ScreenLink(url: URL(string: "familyplanner://s4")!), .setup(4))
        XCTAssertNil(ScreenLink(url: URL(string: "familyplanner://s5")!))
    }

    /// A setup link opens at once, filled with the sample family; nothing is saved until Start.
    func testSetupLinkOpensAtTheStep() async {
        let saved = LockIsolated(0)
        let store = store(kids: SeedData.kids)
        store.dependencies.scheduleStore.replaceFamily = { _ in saved.withValue { $0 += 1 } }
        await store.send(.checkFamily)
        await store.receive(\.familyChecked)
        await store.send(.linkOpened(.setup(3)))
        XCTAssertEqual(store.state.setup?.step, .gettingThere(0))
        XCTAssertNil(store.state.lock)
        await store.send(.linkOpened(.setup(2)))
        XCTAssertEqual(store.state.setup?.step, .school)
        XCTAssertEqual(saved.value, 0)
    }

    func testLoadSampleFamilyClosesEverythingAndReloads() async {
        let store = store(kids: [])
        await store.send(.checkFamily)
        await store.receive(\.familyChecked)
        await store.send(.familyReplaced)
        XCTAssertNil(store.state.setup)
        XCTAssertEqual(store.state.hasFamily, true)
        await store.receive(\.home.reload)
    }
}
