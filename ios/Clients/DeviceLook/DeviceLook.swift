import ComposableArchitecture

/// The iPad's own light or dark setting (Settings › Display), which grown-up screens follow (spec
/// "Night mapping"). The window's colour scheme is set by the app, so views cannot see the
/// system's own choice; this port reads it.
@DependencyClient
public struct DeviceLookClient: Sendable {
    public var isDark: @Sendable () -> Bool = { false }
}

extension DeviceLookClient: TestDependencyKey {
    /// Tests run in the light look; override `isDark` for the dark one.
    public static let testValue = Self(isDark: { false })
    public static let previewValue = Self(isDark: { false })
}

extension DependencyValues {
    public var deviceLook: DeviceLookClient {
        get { self[DeviceLookClient.self] }
        set { self[DeviceLookClient.self] = newValue }
    }
}
