import AppCore
import ComposableArchitecture
import ParentAuthClient
import SwiftUI
import XCTest

@MainActor
final class AppFeatureTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_800_000_000)   // 08:00 UTC
    private let minuteOfFixedDate = 480

    func testClockTicksEverySecondUntilCancelled() async {
        let clock = TestClock()
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = clock
            $0.date.now = fixedDate
            $0.calendar = {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = TimeZone(identifier: "UTC")!
                return calendar
            }()
        }

        let task = await store.send(.task)
        await clock.advance(by: .seconds(1))
        await store.receive(\.tick, fixedDate) {
            $0.now = self.fixedDate
        }
        // Before the home screen's first load a tick only moves its minute.
        await store.receive(\.home.tick, fixedDate) {
            $0.home.minute = self.minuteOfFixedDate
        }
        await clock.advance(by: .seconds(1))
        await store.receive(\.tick, fixedDate)
        await store.receive(\.home.tick, fixedDate)
        await task.cancel()
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
