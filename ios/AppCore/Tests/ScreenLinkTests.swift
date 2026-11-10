import AppCore
import ComposableArchitecture
import Domain
import Grownup
import Home
import ParentAuthClient
import ScheduleStore
import XCTest

@MainActor
final class ScreenLinkTests: XCTestCase {
    func testLinksName() {
        XCTAssertEqual(ScreenLink(url: URL(string: "familyplanner://missions")!), .missions)
        XCTAssertEqual(ScreenLink(url: URL(string: "familyplanner://home")!), .home)
        XCTAssertEqual(ScreenLink(url: URL(string: "familyplanner://c2")!), .grownup(.c2))
        XCTAssertEqual(ScreenLink(url: URL(string: "familyplanner://f4")!), .grownup(.f4))
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

    /// A home with the family loaded: grown-up mode opens on Our day (board G1).
    private func homeWithFamily() -> AppFeature.State {
        var state = AppFeature.State()
        state.home.days = SeedData.kids.map { HomeFeature.KidDay(kid: $0, dayType: .weekday, slots: []) }
        return state
    }

    /// With the lock off, a link at launch waits for the home's kids, then opens Our day (not Settings).
    func testLinkBeforeTheHomeLoadsWaitsForItsKids() async {
        var state = AppFeature.State()
        state.grownupLock = false
        state.hasFamily = true
        state.home.today = Day(year: 2027, month: 1, day: 15)
        let store = TestStore(initialState: state) { AppFeature() } withDependencies: {
            $0.date.now = Date(timeIntervalSince1970: 1_800_000_000)
            $0.calendar = Calendar(identifier: .gregorian)
        }
        store.exhaustivity = .off
        await store.send(.linkOpened(.grownup(.c6)))
        XCTAssertTrue(store.state.path.isEmpty)
        XCTAssertTrue(store.state.opensGrownupOnHomeLoad)
        await store.send(.home(.loaded(snapshot(), family: FamilyCalendar())))
        guard case .ourDay = store.state.path.first else { return XCTFail("\(store.state.path)") }
        XCTAssertFalse(store.state.opensGrownupOnHomeLoad)
    }

    /// A relock (another link, idle, the app leaving) drops a grown-up open still waiting for the home.
    func testARelockDropsTheWaitingOpen() async {
        var state = AppFeature.State()
        state.grownupLock = false
        state.hasFamily = true
        state.home.today = Day(year: 2027, month: 1, day: 15)
        let store = TestStore(initialState: state) { AppFeature() } withDependencies: {
            $0.date.now = Date(timeIntervalSince1970: 1_800_000_000)
            $0.calendar = Calendar(identifier: .gregorian)
        }
        store.exhaustivity = .off
        await store.send(.linkOpened(.grownup(.c6)))
        XCTAssertTrue(store.state.opensGrownupOnHomeLoad)
        await store.send(.linkOpened(.home))
        XCTAssertFalse(store.state.opensGrownupOnHomeLoad)
        await store.send(.home(.loaded(snapshot(), family: FamilyCalendar())))
        XCTAssertTrue(store.state.path.isEmpty, "no grown-up screen without a new gate")
    }

    /// After the unlock Our day opens, and once it has loaded the link's board follows.
    func testGrownupLinkOpensItsBoardAfterTheUnlock() async {
        let store = TestStore(initialState: homeWithFamily()) { AppFeature() } withDependencies: {
            $0.parentAuth.authenticate = { _ in .success }
            $0.date.now = Date(timeIntervalSince1970: 1_800_000_000)
            $0.calendar = Calendar(identifier: .gregorian)
        }
        store.exhaustivity = .off
        await store.send(.linkOpened(.grownup(.c2)))
        await store.receive(\.parentAuthResponse)
        guard case .ourDay = store.state.path.first else { return XCTFail("\(store.state.path)") }
        await store.send(.path(.element(id: 0, action: .ourDay(.loaded(snapshot())))))
        guard case .busSettings = store.state.path.last else { return XCTFail("\(store.state.path)") }
        XCTAssertNil(store.state.pendingBoard)
    }

    /// A link over open grown-up screens closes them; the next board asks for Face ID again.
    func testLinkOverGrownupScreensLocksThem() async {
        let asked = LockIsolated(0)
        var state = AppFeature.State()
        state.path.append(.settings(SettingsFeature.State()))
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
        let store = TestStore(initialState: homeWithFamily()) { AppFeature() } withDependencies: {
            $0.parentAuth.authenticate = { _ in .success }
            $0.date.now = Date(timeIntervalSince1970: 1_800_000_000)
            $0.calendar = Calendar(identifier: .gregorian)
        }
        store.exhaustivity = .off
        await store.send(.linkOpened(.grownup(.e6)))
        await store.receive(\.parentAuthResponse)
        await store.send(.path(.element(id: 0, action: .ourDay(.loaded(snapshot())))))
        guard case let .settings(hub) = store.state.path.last else { return XCTFail("\(store.state.path)") }
        XCTAssertEqual(hub.selectedKid, SeedData.kids[1].id)
    }
}
