import AppCore
import ComposableArchitecture
import DesignSystem
import DeviceLook
import Domain
import Grownup
import KeyboardClient
import Localization
import Missions
import ScheduleStore
import ParentAuthClient
import SwiftUI
import XCTest

@MainActor
final class AppFeatureTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_800_000_000)   // 08:00 UTC
    private let minuteOfFixedDate = 480

    /// Spec "Keyboard": the one keyboard client's changes reach the app state (every screen reads
    /// `keyboardTop` from there); a floating keyboard arrives as no keyboard.
    func testKeyboardChangesReachTheState() async {
        let (changes, continuation) = AsyncStream.makeStream(of: KeyboardChange.self)
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.continuousClock = TestClock()
            $0.date.now = fixedDate
            $0.keyboard.changes = { changes }
        }
        store.exhaustivity = .off
        let task = await store.send(.task)
        continuation.yield(KeyboardChange(top: 398, duration: 0.3))
        await store.receive(\.keyboardChanged) {
            $0.keyboardTop = 398
            $0.keyboardDuration = 0.3
        }
        continuation.yield(KeyboardChange(top: nil, duration: 0.25))
        await store.receive(\.keyboardChanged) { $0.keyboardTop = nil }
        await task.cancel()
    }

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

    /// Spec G5: "Details ›" on G1 opens G2 on the day on the clock; the List opens it on no day
    /// (its "Change from when?" then starts on Today).
    func testOurDayOpensAnItemOnTheDayBeingLookedAt() async {
        let later = Day(year: 2026, month: 11, day: 18)
        let swim = ScheduleItem(id: UUID(), title: "Swimming", iconName: "actSwim", audience: .kid(SeedData.kidA.id),
                                start: 930, end: 990,
                                recurrence: .weekly([.wednesday], from: Day(year: 2026, month: 11, day: 1), until: nil),
                                skippedDays: [], skipsHolidays: true, showsStar: false)
        var ourDay = OurDayFeature.State(kid: SeedData.kidA.id, today: Day(year: 2026, month: 11, day: 10),
                                         calendar: Calendar(identifier: .gregorian))
        ourDay.day = later
        ourDay.items = [swim]
        var state = AppFeature.State()
        state.path.append(.ourDay(ourDay))
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.date.now = fixedDate
            $0.calendar = Calendar(identifier: .gregorian)
        }
        store.exhaustivity = .off
        await store.send(\.path[id: 0].ourDay.delegate.openItem, swim.id)
        guard case let .editor(editor) = store.state.path.last else { return XCTFail("no editor") }
        XCTAssertEqual(editor.shownDay, later)
        await store.send(\.path[id: 1].editor.delegate.finished)
        XCTAssertEqual(store.state.path.count, 1)
        await store.send(\.path[id: 0].ourDay.listTapped)
        await store.send(\.path[id: 0].ourDay.delegate.openItem, swim.id)
        guard case let .editor(fromList) = store.state.path.last else { return XCTFail("no editor") }
        XCTAssertNil(fromList.shownDay, "from the List")
    }

    /// "Missions →" opens A2-MVP over home (a kid screen, not a grown-up one); finishing closes it.
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

    /// Views hold no values: the root's home State and a child State the reducer builds both keep
    /// the store's injected localizer, so State copy follows it.
    func testStatesKeepTheStoresLocalizer() async {
        let store = TestStore(initialState: AppFeature.State()) {
            AppFeature()
        } withDependencies: {
            $0.date.now = fixedDate
            $0.calendar = Calendar(identifier: .gregorian)
            $0.localizer = .keys
        }
        store.exhaustivity = .off
        XCTAssertEqual(store.state.home.strings, .keys)
        XCTAssertEqual(store.state.home.nextLabel, "home.next")
        await store.send(.home(.missionsTapped))
        guard case let .missions(missions)? = store.state.path.first else { return XCTFail("missions not open") }
        XCTAssertEqual(missions.strings, .keys)
        XCTAssertEqual(missions.slideDoneTitle, "missions.ready")
    }

    /// The lock card's words come from State (board C0): one button while scanning or locked out.
    func testLockCardWords() {
        var state = AppFeature.State()
        XCTAssertNil(state.lockCard)
        state.lock = .scanning
        XCTAssertEqual(state.lockCard, AppFeature.State.LockCard(title: "Grown-ups only", message: "Look at the iPad to unlock.",
                                                                 primary: nil, cancel: "Cancel"))
        state.lock = .notRecognised
        XCTAssertEqual(state.lockCard?.primary, "Try again")
        state.lock = .notAvailable(touchID: true)
        XCTAssertEqual(state.lockCard?.primary, "Enter")
        XCTAssertTrue(state.lockCard?.message.hasPrefix("Touch ID is off") == true)
        state.lock = .lockedOut
        XCTAssertNil(state.lockCard?.primary)
        XCTAssertEqual(state.lockCard?.cancel, "OK")

        var keyed = withDependencies { $0.localizer = .keys } operation: { AppFeature.State() }
        keyed.lock = .notAvailable(touchID: false)
        XCTAssertEqual(keyed.lockCard, AppFeature.State.LockCard(title: "lock.title", message: "lock.off.face_id",
                                                                 primary: "lock.enter", cancel: "lock.cancel"))
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

    /// Spec "Several buses" (v61): a change pill on C2 opens its C2c with C2's stop and buses; what
    /// C2c saves goes back to C2, which saves the route. ← on C2c just closes it.
    func testC2OpensC2cAndSavesWhatComesBack() async {
        var c2 = BusSettingsFeature.State(kid: SeedData.kidA.id)
        c2.search = StopSearchFeature.State(stop: "00000")
        c2.search.servicesAtStop = ["1", "2"]
        c2.services = ["1"]
        let first = BusChange(firstBuses: ["1", "2"], thenBus: "4")
        c2.changes = [first]
        var state = AppFeature.State()
        state.path.append(.settings(SettingsFeature.State()))
        state.path.append(.busSettings(c2))
        let saved = LockIsolated<[BusPlan]>([])
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.date.now = self.fixedDate
            $0.scheduleStore.saveBusPlan = { plan in saved.withValue { $0.append(plan) } }
        }
        store.exhaustivity = .off
        await store.send(\.path[id: 1].busSettings.changeTapped, 0)
        await store.receive(\.path[id: 1].busSettings.delegate.openChange)
        guard case let .changeBuses(c2c) = store.state.path.last else { return XCTFail("\(store.state.path)") }
        XCTAssertEqual(c2c.original, first)
        XCTAssertEqual(c2c.ourStop.servicesAtStop, ["1", "2"])
        let edited = BusChange(firstBus: "2", thenBus: "4")
        await store.send(\.path[id: 2].changeBuses.delegate.saved, [edited])
        await store.receive(\.path[id: 1].busSettings.changesSaved)
        XCTAssertEqual(store.state.path.count, 2, "back on C2")
        guard case let .busSettings(back) = store.state.path.last else { return XCTFail("\(store.state.path)") }
        XCTAssertEqual(back.changes, [edited])
        await store.finish()
        XCTAssertEqual(saved.value.last?.changes, [edited])
        // A new one, left with ←: C2 stays as it was.
        await store.send(\.path[id: 1].busSettings.changeLinkTapped)
        await store.receive(\.path[id: 1].busSettings.delegate.openChange)
        guard case let .changeBuses(fresh) = store.state.path.last else { return XCTFail("\(store.state.path)") }
        XCTAssertNil(fresh.original)
        await store.send(\.path[id: 3].changeBuses.delegate.cancelled)
        XCTAssertEqual(store.state.path.count, 2)
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

    /// Settings turning the lock off or on changes the app's gate at once (not after a relaunch).
    func testSettingsLockChangeReachesTheGate() async {
        var state = AppFeature.State()
        state.path.append(.settings(SettingsFeature.State(kid: SeedData.kidA.id)))
        let store = TestStore(initialState: state) { AppFeature() } withDependencies: {
            $0.date.now = self.fixedDate
        }
        store.exhaustivity = .off
        XCTAssertTrue(store.state.grownupLock)
        await store.send(\.path[id: 0].settings.delegate.grownupLockChanged, false)
        XCTAssertFalse(store.state.grownupLock)
        await store.send(\.path[id: 0].settings.delegate.grownupLockChanged, true)
        XCTAssertTrue(store.state.grownupLock)
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

    /// Spec "Sizing → Place": the window around the board frame takes the top screen's page: the
    /// home's look (the night sky at night), the morning screen's, and paper on grown-up screens.
    func testThePageAroundTheBoardFollowsTheTopScreen() {
        var state = AppFeature.State()
        state.home.skyOverride = .night
        XCTAssertEqual(state.pageLook, .night)
        state.path.append(.missions(MissionsFeature.State(look: .night)))
        XCTAssertEqual(state.pageLook, .night)
        state.path.append(.settings(SettingsFeature.State()))
        XCTAssertEqual(state.pageLook, .day, "grown-up screens are paper")
    }
}
