import ComposableArchitecture

/// The feature switches of S4 "Almost done" and Settings' Family tab, all on by default. Live bus
/// times have no switch since layout v44: they are always on, and the timetable look is the fallback.
/// A stored `liveBusTimes` from before is ignored when it loads.
public struct AppSettings: Equatable, Codable, Sendable {
    /// Face ID before grown-up screens. Per iPad: off leaves the 2 s hold as the only gate.
    public var grownupLock: Bool
    /// Gold, silver and bronze for leaving on time. Family setting: off means no medal anywhere.
    public var medals: Bool

    public init(grownupLock: Bool = true, medals: Bool = true) {
        self.grownupLock = grownupLock
        self.medals = medals
    }

    public static let defaults = AppSettings()
}

/// Reads and writes the switches. Features depend on this interface only.
@DependencyClient
public struct AppSettingsClient: Sendable {
    public var load: @Sendable () -> AppSettings = { .defaults }
    public var save: @Sendable (_ settings: AppSettings) -> Void
}

extension AppSettingsClient: TestDependencyKey {
    /// Tests start with every switch on; override `load` for a switch that is off.
    public static let testValue = Self(load: { .defaults }, save: { _ in })
    public static let previewValue = Self(load: { .defaults }, save: { _ in })
}

extension DependencyValues {
    public var appSettings: AppSettingsClient {
        get { self[AppSettingsClient.self] }
        set { self[AppSettingsClient.self] = newValue }
    }
}
