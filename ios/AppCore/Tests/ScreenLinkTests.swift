import AppCore
import ComposableArchitecture
import XCTest

@MainActor
final class ScreenLinkTests: XCTestCase {
    func testLinksName() {
        XCTAssertEqual(ScreenLink(url: URL(string: "familyplanner://missions")!), .missions)
        XCTAssertEqual(ScreenLink(url: URL(string: "familyplanner://home")!), .home)
        XCTAssertNil(ScreenLink(url: URL(string: "familyplanner://grownup")!))
        XCTAssertNil(ScreenLink(url: URL(string: "https://missions")!))
    }

    func testMissionsLinkOpensTheMorning() async {
        let store = TestStore(initialState: AppFeature.State()) { AppFeature() }
        store.exhaustivity = .off
        await store.send(.linkOpened(.missions))
        XCTAssertNotNil(store.state.missions)
        await store.send(.linkOpened(.home))
        XCTAssertNil(store.state.missions)
    }
}
