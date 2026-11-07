#if DEBUG
import ComposableArchitecture
import Foundation
import Observation
import ParentAuthClient

/// What the debug bubble and menu show and change. Every change goes to `core` (read by the app's
/// `\.date` and Face ID) and to UserDefaults.
@MainActor
@Observable
public final class DebugModel {
    public let core: DebugCore
    public let calendar: Calendar
    @ObservationIgnored private let defaults: UserDefaults

    public var settings: DebugSettings {
        didSet {
            core.update(settings)
            DebugSettings.save(settings, to: defaults)
        }
    }

    public var isMenuShown = false

    /// The installed model for views: a view's `@Dependency` reads the default values, not the ones
    /// `bootstrap` gave the store, so `DebugOverlay` finds the model here.
    public private(set) static var installed: DebugModel?

    public init(core: DebugCore, defaults: UserDefaults, calendar: Calendar) {
        self.core = core
        self.defaults = defaults
        self.calendar = calendar
        settings = DebugSettings.load(from: defaults)
        core.update(settings)
    }

    public var isTravelling: Bool { settings.time != nil }

    public func travel(to date: Date) {
        settings.time = TimeTravel(anchor: date, realAnchor: core.realDate(), speed: settings.time?.speed ?? 1)
    }

    public func setSpeed(_ speed: Double) {
        let real = core.realDate()
        settings.time = (settings.time ?? TimeTravel(anchor: real, realAnchor: real, speed: 1))
            .withSpeed(speed, realNow: real)
    }

    public func backToRealTime() { settings.time = nil }

    /// `hour:minute` on the travelled day plus `dayOffset` days.
    public func preset(dayOffset: Int, hour: Int, minute: Int) -> Date {
        let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: core.now())) ?? core.now()
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
}

extension DebugModel {
    /// Debug builds only (`AppDelegate.bootstrap`): the app clock runs on the time machine, and the
    /// "Skip Face ID" flag opens grown-up screens at once. Launch arguments `-fpNow` / `-fpSpeed` set the time.
    public static func install(into dependencies: inout DependencyValues,
                               arguments: [String] = ProcessInfo.processInfo.arguments,
                               defaults: UserDefaults = .standard) {
        let core = DebugCore(settings: DebugSettings())
        let model = DebugModel(core: core, defaults: defaults, calendar: dependencies.calendar)
        model.settings.apply(LaunchOptions(arguments: arguments, calendar: dependencies.calendar),
                             realNow: core.realDate())
        dependencies.date = DateGenerator { core.now() }
        let live = dependencies.parentAuth
        dependencies.parentAuth.authenticate = { reason in
            core.skipsFaceID ? .success : await live.authenticate(reason)
        }
        dependencies.debugTools = model
        installed = model
    }
}

private enum DebugToolsKey: DependencyKey {
    static let liveValue: DebugModel? = nil
    static let testValue: DebugModel? = nil
}

extension DependencyValues {
    /// The debug bubble's model; `nil` unless `DebugModel.install` ran (tests, previews, release).
    public var debugTools: DebugModel? {
        get { self[DebugToolsKey.self] }
        set { self[DebugToolsKey.self] = newValue }
    }
}
#endif
