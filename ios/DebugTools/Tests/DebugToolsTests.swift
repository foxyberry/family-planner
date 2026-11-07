import ComposableArchitecture
import CoreGraphics
@testable import DebugTools
import Foundation
import ParentAuthClient
import XCTest

final class TimeTravelTests: XCTestCase {
    private let real0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testRealTimeWhenNotTravelling() {
        XCTAssertEqual(TimeTravel.now(setting: nil, realNow: real0), real0)
    }

    func testFakeTimeRunsFromTheAnchorAtTheChosenSpeed() {
        let fake0 = real0.addingTimeInterval(86_400)
        let setting = TimeTravel(anchor: fake0, realAnchor: real0, speed: 60)
        XCTAssertEqual(TimeTravel.now(setting: setting, realNow: real0), fake0)
        XCTAssertEqual(TimeTravel.now(setting: setting, realNow: real0.addingTimeInterval(2)),
                       fake0.addingTimeInterval(120))
    }

    func testChangingSpeedKeepsTheCurrentFakeTime() {
        let setting = TimeTravel(anchor: real0, realAnchor: real0, speed: 60)
        let later = real0.addingTimeInterval(10)
        let slowed = setting.withSpeed(1, realNow: later)
        XCTAssertEqual(TimeTravel.now(setting: slowed, realNow: later), real0.addingTimeInterval(600))
        XCTAssertEqual(TimeTravel.now(setting: slowed, realNow: later.addingTimeInterval(5)),
                       real0.addingTimeInterval(605))
    }
}

final class LaunchOptionsTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return calendar
    }

    func testReadsNowAndSpeed() {
        let options = LaunchOptions(arguments: ["App", "-fpNow", "2026-11-09T07:30", "-fpSpeed", "60"],
                                    calendar: calendar)
        let expected = calendar.date(from: DateComponents(year: 2026, month: 11, day: 9, hour: 7, minute: 30))
        XCTAssertEqual(options.now, expected)
        XCTAssertEqual(options.speed, 60)
    }

    func testIgnoresMissingOrBadValues() {
        let options = LaunchOptions(arguments: ["App", "-fpNow", "tomorrow", "-fpSpeed"], calendar: calendar)
        XCTAssertNil(options.now)
        XCTAssertNil(options.speed)
    }
}

final class BubbleDockTests: XCTestCase {
    private let screen = CGSize(width: 1366, height: 1024)
    private let size: CGFloat = 64

    func testDropsOnTheNearerSideFullyVisible() {
        let left = BubbleDock(drop: CGPoint(x: 400, y: 500), screen: screen, size: size)
        XCTAssertEqual(left.side, .leading)
        XCTAssertFalse(left.tucked)
        XCTAssertEqual(left.center(in: screen, size: size).x, BubbleDock.inset + size / 2)

        let right = BubbleDock(drop: CGPoint(x: 1000, y: 500), screen: screen, size: size)
        XCTAssertEqual(right.side, .trailing)
        XCTAssertEqual(right.center(in: screen, size: size).x, screen.width - BubbleDock.inset - size / 2)
    }

    func testPushedIntoTheEdgeTucksHalfAway() {
        let dock = BubbleDock(drop: CGPoint(x: 1350, y: 500), screen: screen, size: size)
        XCTAssertTrue(dock.tucked)
        XCTAssertEqual(dock.center(in: screen, size: size).x, screen.width, "half of it shows")
    }

    func testHeightIsKeptAsAShareAndClampedOnScreen() {
        let dock = BubbleDock(drop: CGPoint(x: 10, y: 2000), screen: screen, size: size)
        let center = dock.center(in: screen, size: size)
        XCTAssertEqual(center.y, screen.height - BubbleDock.inset - size / 2)
        let rotated = dock.center(in: CGSize(width: 1024, height: 1366), size: size)
        XCTAssertEqual(rotated.y, 1366 - BubbleDock.inset - size / 2)
    }

    func testUntuckShowsItWhole() {
        var dock = BubbleDock(drop: CGPoint(x: 5, y: 500), screen: screen, size: size)
        XCTAssertTrue(dock.tucked)
        dock.tucked = false
        XCTAssertEqual(dock.center(in: screen, size: size).x, BubbleDock.inset + size / 2)
    }
}

final class DebugSettingsStoreTests: XCTestCase {
    func testSettingsSurviveARelaunch() throws {
        let suite = "fp.debug.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        var settings = DebugSettings()
        settings.showsLayoutGrid = true
        settings.skipsFaceID = true
        settings.time = TimeTravel(anchor: Date(timeIntervalSince1970: 1), realAnchor: Date(timeIntervalSince1970: 2),
                                   speed: 10)
        DebugSettings.save(settings, to: defaults)
        XCTAssertEqual(DebugSettings.load(from: defaults), settings)
    }

    func testFreshInstallStartsWithEverythingOff() throws {
        let suite = "fp.debug.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        XCTAssertEqual(DebugSettings.load(from: defaults), DebugSettings())
    }

    func testLaunchArgumentsStartTimeTravelFromNow() {
        let fake = Date(timeIntervalSince1970: 1_900_000_000)
        let real = Date(timeIntervalSince1970: 1_800_000_000)
        var settings = DebugSettings()
        settings.apply(LaunchOptions(now: fake, speed: nil), realNow: real)
        XCTAssertEqual(settings.time, TimeTravel(anchor: fake, realAnchor: real, speed: 1))
        settings.apply(LaunchOptions(now: nil, speed: 60), realNow: real)
        XCTAssertEqual(settings.time?.speed, 60, "speed alone keeps the travelled time")
    }
}

final class DebugCoreTests: XCTestCase {
    func testDateAndFaceIDReadTheLatestSettings() {
        let real = Date(timeIntervalSince1970: 1_800_000_000)
        let core = DebugCore(settings: DebugSettings(), realNow: { real })
        XCTAssertEqual(core.now(), real)
        XCTAssertFalse(core.skipsFaceID)
        var settings = DebugSettings()
        settings.time = TimeTravel(anchor: real.addingTimeInterval(60), realAnchor: real, speed: 1)
        settings.skipsFaceID = true
        core.update(settings)
        XCTAssertEqual(core.now(), real.addingTimeInterval(60))
        XCTAssertTrue(core.skipsFaceID)
    }
}

@MainActor
final class DebugModelTests: XCTestCase {
    private let real = Date(timeIntervalSince1970: 1_800_000_000)

    private func model() throws -> (DebugModel, UserDefaults) {
        let suite = "fp.debug.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let core = DebugCore(settings: DebugSettings(), realNow: { [real] in real })
        return (DebugModel(core: core, defaults: defaults, calendar: Calendar(identifier: .gregorian)), defaults)
    }

    func testTravelSavesAndFeedsTheAppClock() throws {
        let (model, defaults) = try model()
        let target = real.addingTimeInterval(3 * 86_400)
        model.travel(to: target)
        XCTAssertEqual(model.core.now(), target)
        XCTAssertTrue(model.isTravelling)
        XCTAssertEqual(DebugSettings.load(from: defaults).time?.anchor, target)
    }

    func testSpeedAloneStartsFromTheRealTime() throws {
        let (model, _) = try model()
        model.setSpeed(60)
        XCTAssertEqual(model.settings.time, TimeTravel(anchor: real, realAnchor: real, speed: 60))
        model.setSpeed(1)
        XCTAssertEqual(model.settings.time?.speed, 1)
    }

    func testBackToRealTime() throws {
        let (model, _) = try model()
        model.travel(to: real.addingTimeInterval(600))
        model.backToRealTime()
        XCTAssertNil(model.settings.time)
        XCTAssertEqual(model.core.now(), real)
    }

    func testFlagsReachTheCore() throws {
        let (model, _) = try model()
        model.settings.skipsFaceID = true
        XCTAssertTrue(model.core.skipsFaceID)
    }

    func testPresetIsATimeOnTheTravelledDay() throws {
        let (model, _) = try model()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let preset = model.preset(dayOffset: 1, hour: 7, minute: 0)
        let parts = calendar.dateComponents([.hour, .minute], from: preset)
        XCTAssertEqual([parts.hour, parts.minute], [7, 0])
        XCTAssertEqual(calendar.dateComponents([.day], from: calendar.startOfDay(for: real),
                                               to: calendar.startOfDay(for: preset)).day, 1)
    }
}

@MainActor
final class DebugInstallTests: XCTestCase {
    private func installed(outcome: ParentAuthOutcome, arguments: [String] = ["App"]) throws -> DependencyValues {
        let suite = "fp.debug.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        var dependencies = DependencyValues()
        dependencies.calendar = Calendar(identifier: .gregorian)
        dependencies.parentAuth.authenticate = { _ in outcome }
        DebugModel.install(into: &dependencies, arguments: arguments, defaults: defaults)
        return dependencies
    }

    func testSkipFlagOpensWithoutFaceID() async throws {
        let dependencies = try installed(outcome: .notRecognised)
        dependencies.debugTools?.settings.skipsFaceID = true
        let outcome = await dependencies.parentAuth.authenticate("Open grown-up screens")
        XCTAssertEqual(outcome, .success)
    }

    func testLaunchArgumentDrivesTheAppDate() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let dependencies = try installed(outcome: .success, arguments: ["App", "-fpNow", "2026-11-09T07:30"])
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dependencies.date.now)
        XCTAssertEqual([parts.year, parts.month, parts.day, parts.hour, parts.minute], [2026, 11, 9, 7, 30])
    }
}
