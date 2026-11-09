import AppCore
import ComposableArchitecture
import Domain
import Grownup
import ParentAuthClient
import ScheduleStore
import XCTest

@MainActor
final class ScreenLinkTests: XCTestCase {
    func testLinksName() {
        XCTAssertEqual(ScreenLink(url: URL(string: "familyplanner://missions")!), .missions)
        XCTAssertEqual(ScreenLink(url: URL(string: "familyplanner://home")!), .home)
        XCTAssertEqual(ScreenLink(url: URL(string: "familyplanner://c2")!), .grownup(.c2))
        XCTAssertNil(ScreenLink(url: URL(string: "familyplanner://grownup")!))
        XCTAssertNil(ScreenLink(url: URL(string: "https://missions")!))
    }

    func testMissionsLinkOpensTheMorning() async {
        let store = TestStore(initialState: AppFeature.State()) { AppFeature() }
        store.exhaustivity = .off
        await store.send(.linkOpened(.missions))
        XCTAssertTrue(store.state.isShowingMissions)
        await store.send(.linkOpened(.home))
        XCTAssertTrue(store.state.path.isEmpty)
    }

    private func snapshot() -> ScheduleSnapshot {
        ScheduleSnapshot(kids: SeedData.kids, routines: SeedData.routines, items: [])
    }

    /// A grown-up link still asks for the unlock; it opens nothing when Face ID fails.
    func testGrownupLinkNeedsTheUnlock() async {
        let store = TestStore(initialState: AppFeature.State()) { AppFeature() } withDependencies: {
            $0.parentAuth.authenticate = { _ in .cancelled }
        }
        store.exhaustivity = .off
        await store.send(.linkOpened(.grownup(.c2))) { $0.lock = .scanning }
        await store.receive(\.parentAuthResponse)
        XCTAssertTrue(store.state.path.isEmpty)
        XCTAssertNil(store.state.pendingBoard)
    }

    /// After the unlock the hub opens, and once it has loaded the link's board follows.
    func testGrownupLinkOpensItsBoardAfterTheUnlock() async {
        let store = TestStore(initialState: AppFeature.State()) { AppFeature() } withDependencies: {
            $0.parentAuth.authenticate = { _ in .success }
        }
        store.exhaustivity = .off
        await store.send(.linkOpened(.grownup(.c2)))
        await store.receive(\.parentAuthResponse)
        XCTAssertEqual(store.state.path.count, 1)
        await store.send(.path(.element(id: 0, action: .hub(.loaded(snapshot())))))
        await store.receive(\.path)
        guard case .busSettings = store.state.path.last else { return XCTFail("\(store.state.path)") }
        XCTAssertNil(store.state.pendingBoard)
    }

    /// A link over open grown-up screens closes them; the next board asks for Face ID again.
    func testLinkOverGrownupScreensLocksThem() async {
        let asked = LockIsolated(0)
        var state = AppFeature.State()
        state.path.append(.hub(GrownupHubFeature.State()))
        state.grownupIdleSeconds = 0
        let store = TestStore(initialState: state) { AppFeature() } withDependencies: {
            $0.parentAuth.authenticate = { _ in asked.withValue { $0 += 1 }; return .cancelled }
        }
        store.exhaustivity = .off
        await store.send(.linkOpened(.home))
        XCTAssertTrue(store.state.path.isEmpty)
        await store.send(.linkOpened(.grownup(.c3)))
        await store.receive(\.parentAuthResponse)
        XCTAssertEqual(asked.value, 1)
        XCTAssertTrue(store.state.path.isEmpty)
    }

    func testSecondKidLinkPicksTheSecondTab() async {
        let store = TestStore(initialState: AppFeature.State()) { AppFeature() } withDependencies: {
            $0.parentAuth.authenticate = { _ in .success }
        }
        store.exhaustivity = .off
        await store.send(.linkOpened(.grownup(.e6)))
        await store.receive(\.parentAuthResponse)
        await store.send(.path(.element(id: 0, action: .hub(.loaded(snapshot())))))
        await store.receive(\.path)
        guard case let .hub(hub) = store.state.path.last else { return XCTFail("\(store.state.path)") }
        XCTAssertEqual(hub.selectedKid, SeedData.kids[1].id)
    }
}
