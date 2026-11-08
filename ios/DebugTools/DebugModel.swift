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
    /// On a real iPad the bubble sits over the kids' screens, so the menu asks for the grown-up unlock.
    @ObservationIgnored private let requiresUnlock: Bool
    /// The real Face ID check, never the "Skip Face ID" wrapper.
    @ObservationIgnored private let unlock: @Sendable (String) async -> ParentAuthOutcome

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

    public init(core: DebugCore, defaults: UserDefaults, calendar: Calendar, requiresUnlock: Bool = false,
                unlock: @escaping @Sendable (String) async -> ParentAuthOutcome = { _ in .success }) {
        self.core = core
        self.defaults = defaults
        self.calendar = calendar
        self.requiresUnlock = requiresUnlock
        self.unlock = unlock
        settings = DebugSettings.load(from: defaults)
        core.update(settings)
    }

    public var isTravelling: Bool { settings.time != nil }

    /// Opens the menu: at once on a simulator, after Face ID on a device (no Face ID set up opens it,
    /// like the grown-up lock).
    public func menuTapped() async {
        if requiresUnlock {
            switch await unlock("Open the debug menu") {
            case .success, .notAvailable: break
            case .notRecognised, .cancelled, .lockedOut: return
            }
        }
        isMenuShown = true
    }

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
        let live = dependencies.parentAuth
        #if targetEnvironment(simulator)
        let requiresUnlock = false
        #else
        let requiresUnlock = true
        #endif
        let model = DebugModel(core: core, defaults: defaults, calendar: dependencies.calendar,
                               requiresUnlock: requiresUnlock, unlock: live.authenticate)
        model.settings.apply(LaunchOptions(arguments: arguments, calendar: dependencies.calendar),
                             realNow: core.realDate())
        dependencies.date = DateGenerator { core.now() }
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
