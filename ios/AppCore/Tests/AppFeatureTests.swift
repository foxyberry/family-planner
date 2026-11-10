import AppCore
import ComposableArchitecture
import Domain
import Grownup
import ScheduleStore
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
            $0.home.idleSeconds = 1   // the idle wink counts in these ticks
            $0.home.now = self.fixedDate
            $0.home.secondsSinceRefresh = 1   // live bus times count the same ticks
        }
        await clock.advance(by: .seconds(1))
        await store.receive(\.tick, fixedDate)
        await store.receive(\.home.tick, fixedDate) {
            $0.home.idleSeconds = 2
            $0.home.secondsSinceRefresh = 2
        }
        await task.cancel()
    }

    /// Board G1: "←" on Our day leaves grown-up mode; Settings' back returns to Our day.
    func testOurDayBackGoesHomeAndSettingsBackReturns() async {
        var state = AppFeature.State()
        state.path.append(.ourDay(OurDayFeature.State(kid: SeedData.kidA.id, today: Day(year: 2026, month: 11, day: 10),
                                                      calendar: Calendar(identifier: .gregorian))))
        state.path.append(.settings(SettingsFeature.State(kid: SeedData.kidA.id)))
        state.grownupIdleSeconds = 0
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.date.now = self.fixedDate
        }
        store.exhaustivity = .off
        await store.send(\.path[id: 1].settings.backTapped)
        XCTAssertEqual(store.state.path.count, 1)
        await store.send(\.path[id: 0].ourDay.delegate.finished)
        XCTAssertTrue(store.state.path.isEmpty)
        XCTAssertNil(store.state.grownupIdleSeconds)
    }

    func testGalleryButtonPushesGallery() async {
        var state = AppFeature.State()
        state.path.append(.settings(SettingsFeature.State()))
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.date.now = self.fixedDate
        }

        await store.send(\.path[id: 0].settings.galleryButtonTapped) {
            $0.grownupIdleSeconds = 0
            $0.path[id: 1] = .gallery(GalleryFeature.State())
        }
    }

    func testGalleryBackPopsToSettings() async {
        var state = AppFeature.State()
        state.path.append(.settings(SettingsFeature.State()))
        state.path.append(.gallery(GalleryFeature.State()))
        state.grownupIdleSeconds = 5
        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(\.path[id: 1].gallery.backTapped) {
            $0.grownupIdleSeconds = 0
            $0.path.pop(from: 1)
        }
    }

    func testOurDayOpensSettingsAndTheEditor() async {
        var state = AppFeature.State()
        state.path.append(.ourDay(OurDayFeature.State(kid: SeedData.kidB.id, today: Day(year: 2026, month: 11, day: 10),
                                                      calendar: Calendar(identifier: .gregorian))))
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.date.now = fixedDate
            $0.calendar = Calendar(identifier: .gregorian)
        }
        store.exhaustivity = .off
        await store.send(\.path[id: 0].ourDay.delegate.openSettings, SeedData.kidB.id)
        guard case let .settings(hub) = store.state.path[id: 1] else { return XCTFail("no Settings") }
        XCTAssertEqual(hub.selectedKid, SeedData.kidB.id)
        await store.send(\.path[id: 1].settings.backTapped)
        await store.send(\.path[id: 0].ourDay.delegate.add, (SeedData.kidB.id, .weekly))
        guard case let .editor(editor) = store.state.path.last else { return XCTFail("no editor") }
        XCTAssertEqual(editor.mode, .add(.kid(SeedData.kidB.id)))
    }

    /// "Missions →" opens A2-MVP over home (not a grown-up screen: no relock); finishing closes it.
    func testMissionsOpenOverHomeAndClose() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.date.now = fixedDate
            $0.calendar = Calendar(identifier: .gregorian)
        }
        store.exhaustivity = .off
        await store.send(.home(.missionsTapped))
        XCTAssertTrue(store.state.isShowingMissions, "pushed over home")
        XCTAssertFalse(store.state.hasGrownupScreens, "a kid screen: no grown-up rules")
        await store.send(.path(.element(id: 0, action: .missions(.delegate(.finished)))))
        XCTAssertTrue(store.state.path.isEmpty)
    }

    /// The morning screen is a kid screen: going to the background neither closes nor covers it.
    func testMissionsStayWhenTheAppGoesToTheBackground() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.date.now = fixedDate
            $0.calendar = Calendar(identifier: .gregorian)
        }
        store.exhaustivity = .off
        await store.send(.home(.missionsTapped))
        await store.send(.scenePhaseChanged(.background))
        XCTAssertTrue(store.state.isShowingMissions)
        XCTAssertFalse(store.state.coversGrownupScreens)
    }

    func testSettingsMissionsRowOpensTheMissionEditor() async {
        let hub = SettingsFeature.State(kid: SeedData.kidB.id)
        var state = AppFeature.State()
        state.path.append(.settings(hub))
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.date.now = fixedDate
            $0.calendar = Calendar(identifier: .gregorian)
        }
        store.exhaustivity = .off
        await store.send(\.path[id: 0].settings.missionsRowTapped)
        guard case let .missionEditor(editor) = store.state.path[id: 1] else { return XCTFail("no C5") }
        XCTAssertEqual(editor.selectedKid, SeedData.kidB.id)
        await store.send(\.path[id: 1].missionEditor.delegate.finished)
        XCTAssertEqual(store.state.path.count, 1)
    }

    func testEditorFinishedPopsBack() async {
        var state = AppFeature.State()
        state.path.append(.settings(SettingsFeature.State()))
        state.path.append(.editor(ItemEditorFeature.State(mode: .add(.both), now: fixedDate,
                                                          calendar: Calendar(identifier: .gregorian))))
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.date.now = self.fixedDate
        }
        store.exhaustivity = .off
        await store.send(\.path[id: 1].editor.delegate.finished)
        XCTAssertEqual(store.state.path.count, 1)
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
