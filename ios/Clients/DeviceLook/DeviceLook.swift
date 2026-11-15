import ComposableArchitecture
import CoreGraphics

/// The iPad itself, as the app's look needs it:
/// - `isDark`: its own light or dark setting (Settings › Display), which grown-up screens follow
///   (spec "Night mapping"). The window's colour scheme is set by the app, so views cannot see the
///   system's own choice; this port reads it.
/// - `screen`: the device screen in landscape points (spec "Supported screens and windows"), so
///   the app sizes from the iPad, not from a Split View or Stage Manager window. Nil before the
///   app has a window scene.
@DependencyClient
public struct DeviceLookClient: Sendable {
    public var isDark: @Sendable () -> Bool = { false }
    public var screen: @Sendable () -> CGSize? = { nil }
}

/// Spec "Supported screens and windows": a screen in landscape, the long side as width.
public func landscape(_ size: CGSize) -> CGSize {
    CGSize(width: max(size.width, size.height), height: min(size.width, size.height))
}

extension DeviceLookClient: TestDependencyKey {
    /// Tests run in the light look on the 13" screen; override for others.
    public static let testValue = Self(isDark: { false }, screen: { CGSize(width: 1376, height: 1032) })
    public static let previewValue = Self(isDark: { false }, screen: { CGSize(width: 1376, height: 1032) })
}

extension DependencyValues {
    public var deviceLook: DeviceLookClient {
        get { self[DeviceLookClient.self] }
        set { self[DeviceLookClient.self] = newValue }
    }
}
