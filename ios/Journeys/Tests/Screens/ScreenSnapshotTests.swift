import AppCore
import ComposableArchitecture
import DesignSystem
import Domain
import Grownup
import JourneyWorld
import KitArt
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
