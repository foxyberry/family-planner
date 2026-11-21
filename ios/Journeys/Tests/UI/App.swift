import XCTest

/// The debug app on the simulator, started the way a journey's `WorldData` starts: a pinned time,
/// a known family and Face ID skipped (DebugTools launch flags; fake values only).
@MainActor
enum TestApp {
    /// Tuesday 10 Nov 2026, 7:30 am: a school day (journeys use the same).
    static let now = "2026-11-10T07:30"

    static func launch(family: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-fpNow", now, "-fpFamily", family, "-fpSkipFaceID"]
        app.launch()
        return app
    }
}
