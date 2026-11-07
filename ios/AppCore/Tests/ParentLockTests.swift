@testable import AppCore
import ComposableArchitecture
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
        state.path.append(.parentHome(ParentHomeFeature.State()))
        state.lastGrownupTouch = start
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
            $0.lastGrownupTouch = self.start
            $0.path[id: 0] = .parentHome(ParentHomeFeature.State())
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

    func testFaceIDOffShowsSettingsMessage() async {
        let opened = LockIsolated<URL?>(nil)
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.parentAuth.authenticate = { _ in .notAvailable }
            $0.parentAuth.biometry = { .faceID }
            $0.openURL = OpenURLEffect { url in
                opened.setValue(url)
                return true
            }
        }
        await store.send(.home(.clockHoldCompleted)) { $0.lock = .scanning }
        await store.receive(\.parentAuthResponse, .notAvailable) { $0.lock = .notAvailable(touchID: false) }
        await store.send(.lockPrimaryTapped) { $0.lock = nil }
        XCTAssertEqual(opened.value, AppFeature.settingsURL)
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
        let store = TestStore(initialState: unlockedState()) {
            AppFeature()
        } withDependencies: { [start] in
            $0.date.now = start.addingTimeInterval(95)
            $0.calendar = Calendar(identifier: .gregorian)
        }
        store.exhaustivity = .off
        await store.send(.tick(start.addingTimeInterval(89)))
        XCTAssertNil(store.state.relockCaption)
        await store.send(.tick(start.addingTimeInterval(90)))
        XCTAssertEqual(store.state.relockCaption, "Locks in 0:30")
        await store.send(.tick(start.addingTimeInterval(100)))
        XCTAssertEqual(store.state.relockCaption, "Locks in 0:20")
        await store.send(.grownupTouched)
        XCTAssertNil(store.state.relockCaption)
        XCTAssertEqual(store.state.lastGrownupTouch, start.addingTimeInterval(95))
    }

    func testIdleTwoMinutesRelocksAndDropsUnsavedForm() async {
        var state = unlockedState()
        state.path.append(.gallery(GalleryFeature.State()))   // stands in for an open form
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.calendar = Calendar(identifier: .gregorian)
        }
        store.exhaustivity = .off
        await store.send(.tick(start.addingTimeInterval(119)))
        XCTAssertEqual(store.state.path.count, 2)
        await store.send(.tick(start.addingTimeInterval(120)))
        XCTAssertTrue(store.state.path.isEmpty)
        XCTAssertNil(store.state.lastGrownupTouch)
        XCTAssertNil(store.state.relockCaption)
    }

    func testBackgroundRelocks() async {
        let store = TestStore(initialState: unlockedState()) {
            AppFeature()
        }
        store.exhaustivity = .off
        await store.send(.scenePhaseChanged(.background))
        XCTAssertTrue(store.state.path.isEmpty)
        XCTAssertNil(store.state.lastGrownupTouch)
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
    }
}
