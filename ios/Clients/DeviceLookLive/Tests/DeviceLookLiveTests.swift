import DeviceLook
import DeviceLookLive
import UIKit
import XCTest

/// The live read answers on the main thread with the scene's style (the test host has a scene).
@MainActor
final class DeviceLookLiveTests: XCTestCase {
    func testReadsTheSceneStyle() {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let expected = (scene?.traitCollection ?? UITraitCollection.current).userInterfaceStyle == .dark
        XCTAssertEqual(DeviceLookClient.live.isDark(), expected)
    }

    /// The screen comes back in landscape, long side first, whatever the orientation; nil while the
    /// app has no window scene (the unit test host may have none).
    func testReadsTheScreenInLandscape() {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        if let scene {
            let bounds = scene.screen.bounds.size
            XCTAssertEqual(DeviceLookClient.live.screen(),
                           CGSize(width: max(bounds.width, bounds.height), height: min(bounds.width, bounds.height)))
        } else {
            XCTAssertNil(DeviceLookClient.live.screen())
        }
        XCTAssertEqual(landscape(CGSize(width: 744, height: 1133)), CGSize(width: 1133, height: 744))
    }
}
