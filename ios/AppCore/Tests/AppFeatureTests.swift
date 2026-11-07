import AppCore
import ComposableArchitecture
import ParentAuthClient
import SwiftUI
import XCTest

@MainActor
final class AppFeatureTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_800_000_000)

    func testClockTicksEverySecondUntilCancelled() async {
        let clock = TestClock()
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.date.now = fixedDate
        }

        let task = await store.send(.task)
        await clock.advance(by: .seconds(1))
        await store.receive(\.tick, fixedDate) {
            $0.now = self.fixedDate
        }
        await clock.advance(by: .seconds(1))
        await store.receive(\.tick, fixedDate)
        await task.cancel()
    }

    func testParentButtonAuthorizedPushesParentHome() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.parentAuth.authenticate = { _ in true }
        }

        await store.send(.parentButtonTapped)
        await store.receive(\.parentAuthResponse, true) {
            // Address the element by its ID: append() here would draw a second ID (#1)
            // from the test's stack-ID generator.
            $0.path[id: 0] = .parentHome(ParentHomeFeature.State())
        }
    }

    func testParentButtonDeniedStaysHome() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.parentAuth.authenticate = { _ in false }
        }

        await store.send(.parentButtonTapped)
        await store.receive(\.parentAuthResponse, false)
        XCTAssertTrue(store.state.path.isEmpty)
    }

    func testParentHomeDoneDismisses() async {
        var state = AppFeature.State()
        state.path.append(.parentHome(ParentHomeFeature.State()))
        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(\.path[id: 0].parentHome.doneButtonTapped)
        await store.receive(\.path.popFrom) {
            $0.path = StackState()
        }
    }

    func testGalleryButtonPushesGallery() async {
        var state = AppFeature.State()
        state.path.append(.parentHome(ParentHomeFeature.State()))
        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(\.path[id: 0].parentHome.galleryButtonTapped) {
            $0.path[id: 1] = .gallery(GalleryFeature.State())
        }
    }

    func testAuthenticateReceivesReason() async {
        let reason = LockIsolated<String?>(nil)
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.parentAuth.authenticate = { received in
                reason.setValue(received)
                return false
            }
        }

        await store.send(.parentButtonTapped)
        await store.receive(\.parentAuthResponse, false)
        XCTAssertEqual(reason.value, "Open parent mode")
    }

    func testDidFinishLaunchingHasNoSideEffects() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.appDelegate(.didFinishLaunching))
    }

    func testScenePhaseIsTracked() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        }

        await store.send(.scenePhaseChanged(.active)) {
            $0.scenePhase = .active
        }
        await store.send(.scenePhaseChanged(.background)) {
            $0.scenePhase = .background
        }
    }
}
