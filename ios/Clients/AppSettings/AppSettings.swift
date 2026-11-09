import ComposableArchitecture

/// The feature switches of S4 "Almost done" (and C9 "This iPad" later), all on by default.
public struct AppSettings: Equatable, Codable, Sendable {
    /// Face ID before grown-up screens. Per iPad: off leaves the 2 s hold as the only gate.
    public var grownupLock: Bool
    /// Live bus times from LTA. Family setting: off means the app never calls LTA.
    public var liveBusTimes: Bool
    /// Gold, silver and bronze for leaving on time. Family setting: off means no medal anywhere.
    public var medals: Bool

    public init(grownupLock: Bool = true, liveBusTimes: Bool = true, medals: Bool = true) {
        self.grownupLock = grownupLock
        self.liveBusTimes = liveBusTimes
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
