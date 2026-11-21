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
}
