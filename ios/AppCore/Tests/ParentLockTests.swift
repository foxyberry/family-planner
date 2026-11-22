@testable import AppCore
import AppSettings
import ComposableArchitecture
import DeviceLook
import Domain
import Grownup
import Home
import DesignSystem
import Foundation
import ParentAuthClient
import Setup
import XCTest

/// Board C0: hold the clock, unlock with Face ID only; grown-up screens stay open until "←" or the
/// app goes to the background (spec C0 "Relocking": no idle timer).
@MainActor
final class ParentLockTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func unlockedState() -> AppFeature.State {
        var state = AppFeature.State()
        state.path.append(.settings(SettingsFeature.State()))
        return state
    }

    func testHoldOpensScanningAndSuccessOpensGrownupMode() async {
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
            $0.path[id: 0] = .settings(SettingsFeature.State())
        }
        XCTAssertEqual(reason.value, "Open grown-up screens")
    }

    /// Board G0: the pencil asks for Face ID like the 2 s hold.
    func testPencilAsksForTheUnlock() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.parentAuth.authenticate = { _ in .cancelled }
        }
        await store.send(.home(.pencilTapped)) { $0.lock = .scanning }
        await store.receive(\.parentAuthResponse, .cancelled) { $0.lock = nil }
        XCTAssertTrue(store.state.path.isEmpty)
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
            $0.path[id: 0] = .settings(SettingsFeature.State())
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

    /// Spec C0 "Relocking" (user, 2026-11-22): no idle timer. Minutes of ticks (or a time-machine
    /// jump) leave an open form open, with its unsaved change, and the header keeps "Grown-ups only".
    func testGrownupScreensStayOpenWithoutATouch() async {
        var state = unlockedState()
        state.path.append(.editor(ItemEditorFeature.State(mode: .add(.both), now: start,
                                                          calendar: Calendar(identifier: .gregorian))))
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.calendar = Calendar(identifier: .gregorian)
        }
        store.exhaustivity = .off
        await store.send(\.path[id: 1].editor.binding, .set(\.form.name, "Pottery"))
        for second in 0..<300 { await store.send(.tick(start.addingTimeInterval(Double(second)))) }
        await store.send(.tick(start.addingTimeInterval(3 * 86_400)))
        XCTAssertEqual(store.state.path.count, 2, "still open after 5 minutes")
        guard case let .editor(editor)? = store.state.path.last else { return XCTFail("the form closed") }
        XCTAssertEqual(editor.form.name, "Pottery", "the unsaved change is kept")
    }

    /// Backgrounding still relocks at once: the open form closes, its unsaved change is dropped, and
    /// the next way in asks Face ID again.
    func testBackgroundRelocksAndDropsUnsavedForm() async {
        var state = unlockedState()
        state.path.append(.editor(ItemEditorFeature.State(mode: .add(.both), now: start,
                                                          calendar: Calendar(identifier: .gregorian))))
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: { [start] in
            $0.date.now = start
            $0.parentAuth.authenticate = { _ in .cancelled }
        }
        store.exhaustivity = .off
        await store.send(\.path[id: 1].editor.binding, .set(\.form.name, "Pottery"))
        await store.send(.scenePhaseChanged(.background))
        XCTAssertTrue(store.state.path.isEmpty)
        XCTAssertFalse(store.state.hasGrownupScreens)
        await store.send(.scenePhaseChanged(.active))
        await store.send(.home(.clockHoldCompleted))
        XCTAssertEqual(store.state.lock, .scanning, "Face ID again")
        await store.receive(\.parentAuthResponse)
        XCTAssertTrue(store.state.path.isEmpty, "cancelled: still home, the form is gone")
    }

    /// S4 lock off: the hold opens grown-up screens with no Face ID, there is no app-switcher cover,
    /// and backgrounding still returns home.
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
        XCTAssertTrue(store.state.hasGrownupScreens)
        await store.send(.scenePhaseChanged(.background))
        XCTAssertFalse(store.state.hasGrownupScreens, "back home when the app leaves")
    }

    /// The lock is read again when setup finishes, and a grown-up link opens without Face ID while
    /// it is off.
    func testSetupFinishReadsTheLockAndLinksFollowIt() async {
        let settings = LockIsolated(AppSettings())
        var state = AppFeature.State()
        state.setup = SetupFeature.State(firstKid: UUID(), calendar: Calendar(identifier: .gregorian))
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.appSettings.load = { settings.value }
            $0.parentAuth.authenticate = { _ in .cancelled }
            $0.scheduleStore.load = { throw CancellationError() }
        }
        store.exhaustivity = .off
        XCTAssertTrue(store.state.grownupLock)
        settings.setValue(AppSettings(grownupLock: false))
        await store.send(.setup(.delegate(.finished)))
        XCTAssertFalse(store.state.grownupLock)
        await store.send(.linkOpened(.grownup(.c1)))
        XCTAssertNil(store.state.lock)
        XCTAssertTrue(store.state.opensGrownupOnHomeLoad, "no Face ID; Our day opens once the home has its kids")
    }

    /// A link at launch, before the settings were read, follows the stored lock (off: no Face ID).
    func testALinkAtLaunchReadsTheLockSetting() async {
        var state = AppFeature.State()
        state.hasFamily = true
        state.home.days = SeedData.kids.map { HomeFeature.KidDay(kid: $0, dayType: .weekday, slots: []) }
        let asked = LockIsolated(false)
        let store = TestStore(initialState: state) { AppFeature() } withDependencies: {
            $0.appSettings.load = { AppSettings(grownupLock: false) }
            $0.parentAuth.authenticate = { _ in asked.setValue(true); return .success }
            $0.date.now = Date(timeIntervalSince1970: 1_800_000_000)
            $0.calendar = Calendar(identifier: .gregorian)
        }
        store.exhaustivity = .off
        XCTAssertTrue(store.state.grownupLock, "the default before the settings are read")
        await store.send(.linkOpened(.grownup(.c6)))
        XCTAssertFalse(asked.value)
        XCTAssertTrue(store.state.hasGrownupScreens)
    }

    /// Spec "Night mapping": grown-up screens take the iPad's own look as a value, even over the
    /// night home (going back to nil kept the window dark on the iPad).
    func testGrownupScreensTakeTheDeviceLook() async {
        var state = AppFeature.State()
        state.hasFamily = true
        state.home.days = SeedData.kids.map { HomeFeature.KidDay(kid: $0, dayType: .weekday, slots: []) }
        let dark = LockIsolated(false)
        let store = TestStore(initialState: state) { AppFeature() } withDependencies: {
            $0.appSettings.load = { AppSettings(grownupLock: false) }
            $0.deviceLook.isDark = { dark.value }
            $0.date.now = Date(timeIntervalSince1970: 1_800_000_000)
            $0.calendar = Calendar(identifier: .gregorian)
        }
        store.exhaustivity = .off
        XCTAssertEqual(store.state.colorScheme, .light, "the day home")
        await store.send(.linkOpened(.grownup(.c6)))
        XCTAssertEqual(store.state.colorScheme, .light, "a light iPad")
        dark.setValue(true)
        await store.send(.tick(Date(timeIntervalSince1970: 1_800_000_001)))
        XCTAssertEqual(store.state.colorScheme, .dark, "the iPad turned dark")
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
}
