@testable import AppCore
import AppSettings
import ComposableArchitecture
import Grownup
import DesignSystem
import Foundation
import ParentAuthClient
import XCTest

/// Board C0: hold the clock, unlock with Face ID only, and lock again after 2 idle minutes.
@MainActor
final class ParentLockTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func unlockedState() -> AppFeature.State {
        var state = AppFeature.State()
        state.path.append(.hub(GrownupHubFeature.State()))
        state.grownupIdleSeconds = 0
        return state
    }

    func testHoldOpensScanningAndSuccessPushesHub() async {
        let reason = LockIsolated<String?>(nil)
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: { [start] in
            $0.date.now = start
            $0.parentAuth.authenticate = { received in
                reason.setValue(received)
                return .success
            }
        }
        await store.send(.home(.clockHoldCompleted)) {
            $0.lock = .scanning
        }
        await store.receive(\.parentAuthResponse, .success) {
            $0.lock = nil
            $0.grownupIdleSeconds = 0
            $0.path[id: 0] = .hub(GrownupHubFeature.State())
        }
        XCTAssertEqual(reason.value, "Open grown-up screens")
    }

    func testNotRecognisedShowsTryAgain() async {
        let attempts = LockIsolated(0)
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.parentAuth.authenticate = { _ in
                attempts.withValue { $0 += 1 }
                return .notRecognised
            }
        }
        await store.send(.home(.clockHoldCompleted)) { $0.lock = .scanning }
        await store.receive(\.parentAuthResponse, .notRecognised) { $0.lock = .notRecognised }
        await store.send(.lockPrimaryTapped) { $0.lock = .scanning }
        await store.receive(\.parentAuthResponse, .notRecognised) { $0.lock = .notRecognised }
        XCTAssertEqual(attempts.value, 2)
        XCTAssertTrue(store.state.path.isEmpty)
    }

    func testCancelClosesOverlay() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.parentAuth.authenticate = { _ in .cancelled }
        }
        await store.send(.home(.clockHoldCompleted)) { $0.lock = .scanning }
        await store.receive(\.parentAuthResponse, .cancelled) { $0.lock = nil }
    }

    /// Without Face ID set up, the 2-second hold is the only gate: "Enter" opens grown-up screens.
    func testFaceIDOffOffersEnter() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.parentAuth.authenticate = { _ in .notAvailable }
            $0.parentAuth.biometry = { .faceID }
        }
        await store.send(.home(.clockHoldCompleted)) { $0.lock = .scanning }
        await store.receive(\.parentAuthResponse, .notAvailable) { $0.lock = .notAvailable(touchID: false) }
        await store.send(.lockPrimaryTapped) {
            $0.lock = nil
            $0.grownupIdleSeconds = 0
            $0.path[id: 0] = .hub(GrownupHubFeature.State())
        }
    }

    func testFaceIDOffCancelStaysHome() async {
        var state = AppFeature.State()
        state.lock = .notAvailable(touchID: false)
        let store = TestStore(initialState: state) {
            AppFeature()
        }
        await store.send(.lockCancelTapped) { $0.lock = nil }
        XCTAssertTrue(store.state.path.isEmpty)
    }

    func testLockedOutShowsOK() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.parentAuth.authenticate = { _ in .lockedOut }
        }
        await store.send(.home(.clockHoldCompleted)) { $0.lock = .scanning }
        await store.receive(\.parentAuthResponse, .lockedOut) { $0.lock = .lockedOut }
        await store.send(.lockCancelTapped) { $0.lock = nil }
    }

    func testCountdownCaptionInLast30Seconds() async {
        var state = unlockedState()
        state.grownupIdleSeconds = 88
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.calendar = Calendar(identifier: .gregorian)
        }
        store.exhaustivity = .off
        await store.send(.tick(start))
        XCTAssertNil(store.state.relockCaption)
        await store.send(.tick(start))
        XCTAssertEqual(store.state.relockCaption, "Locks in 0:30")
        for _ in 0..<10 { await store.send(.tick(start)) }
        XCTAssertEqual(store.state.relockCaption, "Locks in 0:20")
        await store.send(.grownupTouched)
        XCTAssertNil(store.state.relockCaption)
        XCTAssertEqual(store.state.grownupIdleSeconds, 0)
    }

    /// The developer time machine moves the clock by days; only real seconds count towards the relock.
    func testClockJumpDoesNotRelock() async {
        let store = TestStore(initialState: unlockedState()) {
            AppFeature()
        } withDependencies: {
            $0.calendar = Calendar(identifier: .gregorian)
        }
        store.exhaustivity = .off
        await store.send(.tick(start.addingTimeInterval(3 * 86_400)))
        XCTAssertEqual(store.state.path.count, 1)
        XCTAssertNil(store.state.relockCaption)
        XCTAssertEqual(store.state.grownupIdleSeconds, 1)
    }

    func testIdleTwoMinutesRelocksAndDropsUnsavedForm() async {
        var state = unlockedState()
        state.grownupIdleSeconds = 118
        state.path.append(.gallery(GalleryFeature.State()))   // stands in for an open form
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.calendar = Calendar(identifier: .gregorian)
        }
        store.exhaustivity = .off
        await store.send(.tick(start))
        XCTAssertEqual(store.state.path.count, 2)
        await store.send(.tick(start))
        XCTAssertTrue(store.state.path.isEmpty)
        XCTAssertNil(store.state.grownupIdleSeconds)
        XCTAssertNil(store.state.relockCaption)
    }

    func testBackgroundRelocks() async {
        let store = TestStore(initialState: unlockedState()) {
            AppFeature()
        }
        store.exhaustivity = .off
        await store.send(.scenePhaseChanged(.background))
        XCTAssertTrue(store.state.path.isEmpty)
        XCTAssertNil(store.state.grownupIdleSeconds)
    }

    /// S4 lock off (layout v17): the hold opens grown-up screens with no Face ID, there is no
    /// app-switcher cover, and the 2-minute return home still applies.
    func testLockOffOpensAfterTheHoldOnly() async {
        let asked = LockIsolated(false)
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
            $0.calendar = calendar
            $0.date.now = Date(timeIntervalSince1970: 1_800_000_000)
            $0.appSettings.load = { AppSettings(grownupLock: false) }
            $0.parentAuth.authenticate = { _ in asked.setValue(true); return .success }
            $0.scheduleStore.load = { throw CancellationError() }
        }
        store.exhaustivity = .off
        await store.send(.checkFamily)
        XCTAssertFalse(store.state.grownupLock)
        await store.send(.home(.clockHoldCompleted))
        XCTAssertNil(store.state.lock)
        XCTAssertTrue(store.state.hasGrownupScreens)
        XCTAssertFalse(asked.value, "no Face ID while the lock is off")
        await store.send(.scenePhaseChanged(.inactive))
        XCTAssertFalse(store.state.coversGrownupScreens)
        await store.send(.scenePhaseChanged(.active))
        for second in 0..<AppFeature.idleLimit { await store.send(.tick(start.addingTimeInterval(Double(second)))) }
        XCTAssertFalse(store.state.hasGrownupScreens, "still back home after 2 idle minutes")
    }

    func testGrownupScreensCoveredWhileNotActive() {
        var state = unlockedState()
        state.scenePhase = .active
        XCTAssertFalse(state.coversGrownupScreens)
        state.scenePhase = .inactive   // app switcher snapshot, Control Center
        XCTAssertTrue(state.coversGrownupScreens)
        var home = AppFeature.State()
        home.scenePhase = .inactive
        XCTAssertFalse(home.coversGrownupScreens, "the kids' home needs no cover")
    }

    func testCoverStaysUpThroughBackgroundRelockUntilActive() async {
        var state = unlockedState()
        state.scenePhase = .active
        let store = TestStore(initialState: state) {
            AppFeature()
        }
        store.exhaustivity = .off
        await store.send(.scenePhaseChanged(.inactive))
        XCTAssertTrue(store.state.coversGrownupScreens)
        await store.send(.scenePhaseChanged(.background))
        XCTAssertTrue(store.state.path.isEmpty, "relocked")
        XCTAssertTrue(store.state.coversGrownupScreens, "still covered while the snapshot is taken")
        await store.send(.scenePhaseChanged(.active))
        XCTAssertFalse(store.state.coversGrownupScreens)
    }

    func testWorkingInAGrownupScreenCountsAsActivity() async {
        var state = unlockedState()
        state.path.append(.editor(ItemEditorFeature.State(mode: .add(.both), now: start,
                                                          calendar: Calendar(identifier: .gregorian))))
        state.grownupIdleSeconds = 110
        state.relockCaption = "Locks in 0:10"
        let store = TestStore(initialState: state) {
            AppFeature()
        }
        store.exhaustivity = .off
        // Typing never reaches the touch gesture (the keyboard is another window); the reducer sees it.
        await store.send(\.path[id: 1].editor.binding, .set(\.form.name, "Pottery"))
        XCTAssertEqual(store.state.grownupIdleSeconds, 0)
        XCTAssertNil(store.state.relockCaption)
    }

    func testIdleTimerIgnoredOnHome() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.calendar = Calendar(identifier: .gregorian)
        }
        store.exhaustivity = .off
        await store.send(.tick(start.addingTimeInterval(500)))
        XCTAssertNil(store.state.relockCaption)
        XCTAssertNil(store.state.grownupIdleSeconds)
    }
}
