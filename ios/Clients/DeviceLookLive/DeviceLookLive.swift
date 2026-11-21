import DeviceLook
import UIKit

extension DeviceLookClient {
    /// The window scene's own trait: the app's `preferredColorScheme` overrides its window, not the
    /// scene, so this is the iPad's setting. Read at call time on the main thread.
    public static let live = Self(isDark: {
        MainActor.assumeIsolated {
            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            return (scene?.traitCollection ?? UITraitCollection.current).userInterfaceStyle == .dark
        }
    })
}
