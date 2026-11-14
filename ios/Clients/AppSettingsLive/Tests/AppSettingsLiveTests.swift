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
        let off = AppSettings(grownupLock: false, medals: true)
        AppSettingsClient.live(defaults: defaults).save(off)
        XCTAssertEqual(AppSettingsClient.live(defaults: defaults).load(), off)
    }

    /// Layout v44: the Live bus times switch is gone; settings saved with it still load.
    func testSettingsSavedWithTheOldLiveSwitchStillLoad() {
        let defaults = freshDefaults()
        defaults.set(Data(#"{"grownupLock":false,"liveBusTimes":false,"medals":true}"#.utf8), forKey: "appSettings")
        XCTAssertEqual(AppSettingsClient.live(defaults: defaults).load(), AppSettings(grownupLock: false, medals: true))
    }
}
