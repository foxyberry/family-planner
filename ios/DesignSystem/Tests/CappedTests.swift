import DesignSystem
import XCTest

final class CappedTests: XCTestCase {
    func testUnderCapShowsAll() {
        let capped = Capped([1, 2], max: 3)
        XCTAssertEqual(capped.visible, [1, 2])
        XCTAssertEqual(capped.overflow, 0)
    }

    func testOverCapCountsOverflow() {
        let capped = Capped([1, 2, 3, 4, 5], max: 3)
        XCTAssertEqual(capped.visible, [1, 2, 3])
        XCTAssertEqual(capped.overflow, 2)
    }

    func testZeroCap() {
        let capped = Capped([1, 2], max: 0)
        XCTAssertEqual(capped.visible, [])
        XCTAssertEqual(capped.overflow, 2)
    }
}
