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
        }
        await clock.advance(by: .seconds(1))
        await store.receive(\.tick, fixedDate)
        await store.receive(\.home.tick, fixedDate)
        await task.cancel()
    }

    func testHubBackGoesHome() async {
        var state = AppFeature.State()
        state.path.append(.hub(GrownupHubFeature.State()))
        state.lastGrownupTouch = fixedDate
        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(\.path[id: 0].hub.backTapped) {
            $0.path = StackState()
            $0.lastGrownupTouch = nil
        }
    }

    func testGalleryButtonPushesGallery() async {
        var state = AppFeature.State()
        state.path.append(.hub(GrownupHubFeature.State()))
        let store = TestStore(initialState: state) {
            AppFeature()
        }

        await store.send(\.path[id: 0].hub.galleryButtonTapped) {
            $0.path[id: 1] = .gallery(GalleryFeature.State())
        }
    }

    func testHubAddEveryWeekPushesEditorForTheTabKid() async {
        var hub = GrownupHubFeature.State()
        hub.selectedKid = SeedData.kidB.id
        var state = AppFeature.State()
        state.path.append(.hub(hub))
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.date.now = fixedDate
            $0.calendar = Calendar(identifier: .gregorian)
        }
        store.exhaustivity = .off
        await store.send(\.path[id: 0].hub.addWeeklyTapped)
        guard case let .editor(editor) = store.state.path[id: 1] else { return XCTFail("no editor") }
        XCTAssertEqual(editor.mode, .add(.kid(SeedData.kidB.id)))
        XCTAssertEqual(editor.form.repeats, .weekly)
    }

    func testHubJustOnceItemOpensEditOnce() async {
        let party = ScheduleItem(id: UUID(), title: "Party", iconName: "cake", audience: .both, start: 960, end: 1020,
                                 recurrence: .once(Day(year: 2027, month: 1, day: 2)), skippedDays: [],
                                 skipsHolidays: false, showsStar: true)
        var hub = GrownupHubFeature.State()
        hub.snapshot = ScheduleSnapshot(kids: SeedData.kids, routines: SeedData.routines, items: [party])
        var state = AppFeature.State()
        state.path.append(.hub(hub))
        let store = TestStore(initialState: state) {
            AppFeature()
        } withDependencies: {
            $0.date.now = fixedDate
            $0.calendar = Calendar(identifier: .gregorian)
        }
        store.exhaustivity = .off
        await store.send(\.path[id: 0].hub.onceItemTapped, party.id)
        guard case let .editor(editor) = store.state.path[id: 1] else { return XCTFail("no editor") }
        XCTAssertEqual(editor.mode, .editOnce(party))
    }

    func testEditorFinishedPopsBackToHub() async {
        var state = AppFeature.State()
        state.path.append(.hub(GrownupHubFeature.State()))
        state.path.append(.editor(ItemEditorFeature.State(mode: .add(.both), now: fixedDate,
                                                          calendar: Calendar(identifier: .gregorian))))
        let store = TestStore(initialState: state) {
            AppFeature()
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
