import AppSettings
import AppSettingsLive
import Foundation
import XCTest

final class AppSettingsLiveTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        let name = "AppSettingsLiveTests-" + UUID().uuidString
        return UserDefaults(suiteName: name)!
    }

    func testANewIPadHasEverySwitchOn() {
        XCTAssertEqual(AppSettingsClient.live(defaults: freshDefaults()).load(), AppSettings.defaults)
    }

    func testSavedSwitchesComeBack() {
        let defaults = freshDefaults()
        let off = AppSettings(grownupLock: false, liveBusTimes: false, medals: true)
        AppSettingsClient.live(defaults: defaults).save(off)
        XCTAssertEqual(AppSettingsClient.live(defaults: defaults).load(), off)
    }
}
