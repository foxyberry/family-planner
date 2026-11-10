#if DEBUG
import ComposableArchitecture
import Domain
import Foundation
import KitArt
import Observation
import ParentAuthClient
import ScheduleStore

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
    /// Writes the sample family over the stored one ("Load sample family").
    @ObservationIgnored private let replaceWithSample: @Sendable () async throws -> Void

    /// Goes up each time "Load sample family" replaced the stored family; the app reloads on it.
    public private(set) var familyGeneration = 0
    /// The last "Load sample family" could not write the store.
    public var sampleFamilyFailed = false

    public var settings: DebugSettings {
        didSet {
            core.update(settings)
            DebugSettings.save(settings, to: defaults)
        }
    }

    public var isMenuShown = false
    /// "Skip Face ID" exists only on a simulator: on a real iPad a forgotten switch would leave
    /// grown-up screens open for good.
    public let allowsSkipFaceID: Bool

    /// The installed model for views: a view's `@Dependency` reads the default values, not the ones
    /// `bootstrap` gave the store, so `DebugOverlay` finds the model here.
    public private(set) static var installed: DebugModel?

    public init(core: DebugCore, defaults: UserDefaults, calendar: Calendar, requiresUnlock: Bool = false,
                allowsSkipFaceID: Bool = true,
                unlock: @escaping @Sendable (String) async -> ParentAuthOutcome = { _ in .success },
                replaceWithSample: @escaping @Sendable () async throws -> Void = {}) {
        self.replaceWithSample = replaceWithSample
        self.allowsSkipFaceID = allowsSkipFaceID
        self.core = core
        self.defaults = defaults
        self.calendar = calendar
        self.requiresUnlock = requiresUnlock
        self.unlock = unlock
        settings = DebugSettings.load(from: defaults)
        core.update(settings)
    }

    public var isTravelling: Bool { settings.time != nil }

    /// The rig scale the kid screens use: the slider's value, else the kit data's.
    public var rigScale: Double { settings.rigScale ?? KitRigs.shared.scale }

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

    /// Debug only (spec "Seed data in M2"): overwrites the stored family with the sample family
    /// (`SeedData`), after the menu's confirm.
    public func loadSampleFamily() async {
        do {
            try await replaceWithSample()
            sampleFamilyFailed = false
            familyGeneration += 1
        } catch {
            sampleFamilyFailed = true
        }
    }

    /// `hour:minute` on the travelled day plus `dayOffset` days.
    public func preset(dayOffset: Int, hour: Int, minute: Int) -> Date {
        let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: core.now())) ?? core.now()
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    }
}

extension DebugModel {
    /// The bubble's pretend time in 24-hour form ("Sat 15:00") in the app calendar's time zone, so
    /// 15:00 never reads as 03:00 (a format style with the am/pm left out stays 12-hour).
    public nonisolated static func bubbleText(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.weekday, .hour, .minute], from: date)
        var symbols = calendar
        symbols.locale = Locale(identifier: "en_US_POSIX")
        let day = symbols.shortWeekdaySymbols[((parts.weekday ?? 1) - 1) % 7]
        return String(format: "%@ %02d:%02d", day, parts.hour ?? 0, parts.minute ?? 0)
    }

    /// Debug builds only (`AppDelegate.bootstrap`): the app clock runs on the time machine, and the
    /// "Skip Face ID" flag opens grown-up screens at once. Launch arguments `-fpNow` / `-fpSpeed` set the time.
    public static func install(into dependencies: inout DependencyValues,
                               arguments: [String] = ProcessInfo.processInfo.arguments,
                               defaults: UserDefaults = .standard,
                               allowsSkipFaceID: Bool = isSimulator) {
        let core = DebugCore(settings: DebugSettings())
        let live = dependencies.parentAuth
        let store = dependencies.scheduleStore
        let calendar = dependencies.calendar
        let model = DebugModel(core: core, defaults: defaults, calendar: calendar,
                               requiresUnlock: !isSimulator, allowsSkipFaceID: allowsSkipFaceID,
                               unlock: live.authenticate,
                               replaceWithSample: {
                                   // Around the app's day, so the time machine sees the sample week.
                                   let today = Day(core.now(), calendar: calendar)
                                   try await store.replaceFamily(.sampleFamily(today: today, calendar: calendar))
                               })
        model.settings.apply(LaunchOptions(arguments: arguments, calendar: dependencies.calendar),
                             realNow: core.realDate())
        dependencies.date = DateGenerator { core.now() }
        if allowsSkipFaceID {
            dependencies.parentAuth.authenticate = { reason in
                core.skipsFaceID ? .success : await live.authenticate(reason)
            }
        }
        dependencies.debugTools = model
        installed = model
    }
}

/// True when this debug build runs on a simulator.
#if targetEnvironment(simulator)
public let isSimulator = true
#else
public let isSimulator = false
#endif

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
