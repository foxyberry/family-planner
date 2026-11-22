import AppCore
import ComposableArchitecture
import DesignSystem
import Domain
import Grownup
import JourneyWorld
import KitArt
import SchoolDirectory
import SnapshotTesting
import SwiftUI
import XCTest

/// Whole screens at journey states, at each iPad size: what a self-check on the iPad looks at
/// (test-layers). Each state is reached by the journey's own steps in its World, then the real
/// AppView draws it. Re-record with `make snapshots-record` from a worktree without private art.
@MainActor
final class ScreenSnapshotTests: XCTestCase {
    /// The 13-inch and the mini, landscape: the largest and smallest screens the app supports.
    private static let sizes: [(name: String, size: CGSize)] = [
        ("13", CGSize(width: 1376, height: 1032)),
        ("mini", CGSize(width: 1133, height: 744)),
    ]

    override func setUp() async throws {
        try await super.setUp()
        XCTAssertTrue(FontRegistrar.registerAll(), "Playpen Sans did not register")
        // Baselines go to a public repo: never record or compare with the private home drawing.
        let art = BundledKitArt()
        try XCTSkipIf(KitSlot.allCases.contains { art.source(for: $0) == .private },
                      "private art is in this build: run screen snapshots from a worktree without it")
    }

    /// The kids' home at 7:30 on a school day, Kid A and Kid B.
    func testHome() async throws {
        let world = World(sample)
        let store = world.store()
        await opened(store)
        for (name, size) in Self.sizes { snap(store.state, world, size: size, named: name) }
    }

    /// Settings for Kid A, pushed over the home.
    func testSettings() async throws {
        let world = World(sample)
        var start = AppFeature.State()
        start.path.append(.settings(SettingsFeature.State(kid: SeedData.kidA.id)))
        let store = world.store(start)
        await opened(store)
        let settings = store.state.path.ids[0]
        await store.send(.path(.element(id: settings, action: .settings(.task))))
        await store.receive(\.path[id: settings].settings.loaded)
        for (name, size) in Self.sizes { snap(store.state, world, size: size, named: name) }
    }

    /// Spec G5 "What Settings shows meanwhile", reached as in SchoolJourneys: G4 saves a new end from
    /// tomorrow; Settings then shows today's hours and "From 11 Nov" under them, and G4 the same line
    /// under When; its row turns G4 to the waiting hours with "Cancel this change", which asks first.
    func testWaitingSchoolHours() async throws {
        let world = World(sample)
        var start = AppFeature.State()
        start.path.append(.settings(SettingsFeature.State(kid: SeedData.kidA.id)))
        let store = world.store(start)
        await opened(store)
        let settings = store.state.path.ids[0]
        await store.send(.path(.element(id: settings, action: .settings(.task))))
        await store.receive(\.path[id: settings].settings.loaded)
        await store.send(.path(.element(id: settings, action: .settings(.schoolRowTapped))))
        let editor = try XCTUnwrap(store.state.path.ids.last)
        await store.send(.path(.element(id: editor, action: .schoolEditor(.task))))
        await store.receive(\.path[id: editor].schoolEditor.loaded)
        let end = world.today.date(minute: 870, calendar: world.calendar)
        await store.send(.path(.element(id: editor, action: .schoolEditor(.endPicked(end)))))
        await store.send(.path(.element(id: editor, action: .schoolEditor(.saveTapped))))
        await store.send(.path(.element(id: editor, action: .schoolEditor(.fromWhenPicked(.next)))))
        await store.send(.path(.element(id: editor, action: .schoolEditor(.fromWhenSaveTapped))))
        await store.receive(\.path[id: editor].schoolEditor.delegate.finished)
        await store.finish()
        await store.skipReceivedActions()
        for (name, size) in Self.sizes { snap(store.state, world, size: size, named: "settings-\(name)") }

        await store.send(.path(.element(id: settings, action: .settings(.schoolRowTapped))))
        let today = try XCTUnwrap(store.state.path.ids.last)
        await store.send(.path(.element(id: today, action: .schoolEditor(.task))))
        await store.receive(\.path[id: today].schoolEditor.loaded)
        snap(store.state, world, size: Self.sizes[0].size, named: "g4-13")
        await store.send(.path(.element(id: today, action: .schoolEditor(.waitingRowTapped))))
        snap(store.state, world, size: Self.sizes[0].size, named: "g4-waiting-13")
        await store.send(.path(.element(id: today, action: .schoolEditor(.cancelChangeTapped))))
        snap(store.state, world, size: Self.sizes[0].size, named: "g4-cancel-13")
    }

    /// A pushed screen with a form card open (C3's Bring card over the new-item editor), at the mini:
    /// the dim reaches the window's sides past the board frame, as it does on the 13-inch (review of
    /// PR 168: the navigation stack clipped pushed screens to the board frame).
    func testFormCardDimAtTheMini() async throws {
        let world = World(sample)
        var start = AppFeature.State()
        start.path.append(.editor(ItemEditorFeature.State(mode: .add(.kid(SeedData.kidA.id)), repeats: .weekly,
                                                          now: world.now, calendar: world.calendar)))
        let store = world.store(start)
        await opened(store)
        let editor = store.state.path.ids[0]
        await store.send(.path(.element(id: editor, action: .editor(.task))))
        await store.receive(\.path[id: editor].editor.loaded)
        await store.send(.path(.element(id: editor, action: .editor(.bringRowTapped))))
        snap(store.state, world, size: Self.sizes[1].size, named: "mini")
    }

    /// The Setup covers (S2 Data sources, S3 Change buses) are hosted outside AppView's board
    /// frame, with only `sizing` from the environment: at the mini their header, form and action
    /// must still sit on one centred board frame (review of PR 168).
    func testCoversAtTheMini() async {
        let mini = Self.sizes[1].size
        // The covers' own tasks (sources, the stop's buses) run in the journey World, never live.
        let world = World(sample)
        var sources = DataSourcesFeature.State()
        sources.sources = [DataSource(name: "Example open data", attribution: "Example attribution",
                                      licenceURL: "https://example.com/licence")]
        snapCover(DataSourcesView(store: Store(initialState: sources) { DataSourcesFeature() } withDependencies: { world.install(&$0) }),
                  size: mini, named: "dataSources.mini")
        let change = ChangeBusesFeature.State(ourStop: StopSearchFeature.State(stop: "12345"), changes: [], index: nil)
        snapCover(ChangeBusesView(store: Store(initialState: change) { ChangeBusesFeature() } withDependencies: { world.install(&$0) }),
                  size: mini, named: "changeBuses.mini")
    }

    /// A screen as a `fullScreenCover` gets it: the window's sizing, the window's whole width.
    private func snapCover(_ screen: some View, size: CGSize, named name: String,
                           file: StaticString = #filePath, testName: String = #function, line: UInt = #line) {
        let view = screen
            .withSizing(Sizing(width: size.width, height: size.height))
            .environment(\.kitArt, BundledKitArt(includePrivate: false))
            .environment(\.locale, Locale(identifier: "en_US_POSIX"))
            .frame(width: size.width, height: size.height)
        let traits = UITraitCollection(traitsFrom: [UITraitCollection(displayScale: 2),
                                                    UITraitCollection(userInterfaceStyle: .light)])
        let failure = verifySnapshot(
            of: view,
            as: .image(layout: .fixed(width: size.width, height: size.height), traits: traits),
            named: name,
            record: ScreenSnapshotLocation.recordDirectory == nil ? .never : .all,
            snapshotDirectory: ScreenSnapshotLocation.directory,
            file: file, testName: testName, line: line
        )
        if let failure { XCTFail(failure, file: file, line: line) }
    }

    /// Our day (board G1) for Kid A: a just-once Piano added with the "+" between Dinner and Shower
    /// and saved, then Dinner picked: "+" on every shared knob, the item on top of Shower, and
    /// Dinner's card with "Skip this day".
    func testOurDay() async throws {
        let world = World(sample)
        let store = world.store()
        await opened(store)
        await store.send(.home(.pencilTapped))
        await store.receive(\.parentAuthResponse)
        let ourDay = store.state.path.ids[0]
        await store.send(.path(.element(id: ourDay, action: .ourDay(.task))))
        await store.receive(\.path[id: ourDay].ourDay.loaded)
        guard case let .ourDay(day)? = store.state.path[id: ourDay],
              let plus = day.addButtons.first(where: { $0.minute == 1155 }) else { return XCTFail("no + at 7:15 pm") }
        await store.send(.path(.element(id: ourDay, action: .ourDay(.addBetweenTapped(plus.knob)))))
        await store.send(.path(.element(id: ourDay, action: .ourDay(.newSlicePicturePicked("actPiano")))))
        await store.send(.path(.element(id: ourDay, action: .ourDay(.saveTapped))))
        await store.receive(\.path[id: ourDay].ourDay.saved)
        await store.receive(\.home.loaded)
        await store.send(.path(.element(id: ourDay, action: .ourDay(.sliceTapped(start: 1110)))))
        for (name, size) in Self.sizes { snap(store.state, world, size: size, named: name) }
    }

    /// Launch as the app does: the store is read once (the home stays paper until then), then the
    /// home loads its day.
    private func opened(_ store: TestStoreOf<AppFeature>) async {
        await store.send(.checkFamily)
        await store.receive(\.familyChecked)
        await store.send(.home(.task))
        await store.receive(\.home.loaded)
    }

    private var sample: WorldData {
        var data = WorldData.standard
        data.family = "sample"
        return data
    }

    /// The real AppView with the journey's State, in its World, at one iPad size.
    private func snap(_ state: AppFeature.State, _ world: World, size: CGSize, named name: String,
                      file: StaticString = #filePath, testName: String = #function, line: UInt = #line) {
        var state = state
        state.scenePhase = .active  // the app is in front, as on the iPad
        let store = Store(initialState: state) { AppFeature() } withDependencies: { world.install(&$0) }
        let view = AppView(store: store)
            .environment(\.kitArt, BundledKitArt(includePrivate: false))
            .environment(\.locale, Locale(identifier: "en_US_POSIX"))
            // An offscreen host is not an active scene, which would draw the app-switcher cover over
            // grown-up screens.
            .environment(\.scenePhase, .active)
            .frame(width: size.width, height: size.height)
        let traits = UITraitCollection(traitsFrom: [UITraitCollection(displayScale: 2),
                                                    UITraitCollection(userInterfaceStyle: .light)])
        let failure = verifySnapshot(
            of: view,
            as: .image(layout: .fixed(width: size.width, height: size.height), traits: traits),
            named: name,
            record: ScreenSnapshotLocation.recordDirectory == nil ? .never : .all,
            snapshotDirectory: ScreenSnapshotLocation.directory,
            file: file, testName: testName, line: line
        )
        if let failure { XCTFail(failure, file: file, line: line) }
    }
}

/// Baselines travel as runfiles; `make snapshots-record` writes new ones through
/// SCREEN_SNAPSHOT_RECORD_DIR.
private enum ScreenSnapshotLocation {
    static let recordDirectory = ProcessInfo.processInfo.environment["SCREEN_SNAPSHOT_RECORD_DIR"]

    static var directory: String {
        if let recordDirectory { return recordDirectory }
        let runfiles = ProcessInfo.processInfo.environment["TEST_SRCDIR"] ?? ""
        return runfiles + "/_main/ios/Journeys/Tests/Screens/__Snapshots__"
    }
}
