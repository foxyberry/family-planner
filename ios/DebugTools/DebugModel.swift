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

    public init(core: DebugCore, defaults: UserDefaults, calendar: Calendar, allowsSkipFaceID: Bool = true,
                replaceWithSample: @escaping @Sendable () async throws -> Void = {}) {
        self.replaceWithSample = replaceWithSample
        self.allowsSkipFaceID = allowsSkipFaceID
        self.core = core
        self.defaults = defaults
        self.calendar = calendar
        settings = DebugSettings.load(from: defaults)
        core.update(settings)
    }

    public var isTravelling: Bool { settings.time != nil }

    /// The rig scale the kid screens use: the slider's value, else the kit data's.
    public var rigScale: Double { settings.rigScale ?? KitRigs.shared.scale }

    /// Opens the menu at once, on a simulator and on a device (user, 2026-11-21: no Face ID for the
    /// debug menu; debug builds only).
    public func menuTapped() async {
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
    /// "Skip Face ID" flag opens grown-up screens at once. Launch arguments `-fpNow` / `-fpSpeed` set the time;
    /// `-fpFamily` sets the starting family (simulators only: a UI test must not wipe a real iPad).
    public static func install(into dependencies: inout DependencyValues,
                               arguments: [String] = ProcessInfo.processInfo.arguments,
                               defaults: UserDefaults = .standard,
                               allowsSkipFaceID: Bool = isSimulator,
                               allowsStartFamily: Bool = isSimulator) {
        let core = DebugCore(settings: DebugSettings())
        let live = dependencies.parentAuth
        let store = dependencies.scheduleStore
        let calendar = dependencies.calendar
        let model = DebugModel(core: core, defaults: defaults, calendar: calendar,
                               allowsSkipFaceID: allowsSkipFaceID,
                               replaceWithSample: {
                                   // Around the app's day, so the time machine sees the sample week.
                                   let today = Day(core.now(), calendar: calendar)
                                   try await store.replaceFamily(.sampleFamily(today: today, calendar: calendar))
                               })
        let options = LaunchOptions(arguments: arguments, calendar: dependencies.calendar)
        model.settings.apply(options, realNow: core.realDate())
        dependencies.date = DateGenerator { core.now() }
        if allowsStartFamily, let start = options.family {
            // Only `load` waits for the replace, so the app never sees the old family. That is
            // enough: every other store call (marks, slides, saves) comes from a screen the app
            // opens after its first load returned. A failed replace makes every load throw, so a
            // UI test stops at its first wait instead of running on the old family.
            let today = Day(core.now(), calendar: calendar)
            let family = start == .sample
                ? ScheduleSnapshot.sampleFamily(today: today, calendar: calendar)
                : ScheduleSnapshot(kids: [], routines: [], items: [])
            let replaced = Task { try await store.replaceFamily(family) }
            dependencies.scheduleStore.load = {
                try await replaced.value
                return try await store.load()
            }
        }
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
