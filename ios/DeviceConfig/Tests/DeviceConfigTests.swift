import DeviceConfig
import XCTest

/// Made-up values only; the real file never reaches the repo.
final class DeviceConfigTests: XCTestCase {
    func testOnlyARealKeyCounts() throws {
        let example = try JSONDecoder().decode(DeviceConfig.self,
                                               from: Data(#"{"busKey":"your-lta-datamall-account-key"}"#.utf8))
        XCTAssertNil(example.usableBusKey, "the example placeholder is not a key")
        XCTAssertEqual(DeviceConfig(busKey: "test-key").usableBusKey, "test-key")
        XCTAssertNil(DeviceConfig(busKey: "").usableBusKey)
    }
}
