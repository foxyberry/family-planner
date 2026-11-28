import DeviceLook
import UIKit

extension DeviceLookClient {
    /// The screen's trait: the app's `preferredColorScheme` overrides its window, and on iOS 26 the
    /// window scene's trait follows that override (issue 021: G1 stayed light on a dark iPad), but the
    /// screen keeps the iPad's own setting. Read at call time on the main thread.
    public static let live = Self(isDark: {
        MainActor.assumeIsolated {
            let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
            return (scene?.screen.traitCollection ?? UITraitCollection.current).userInterfaceStyle == .dark
        }
    })
}
