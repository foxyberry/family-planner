import DesignSystem
import UIKit
import XCTest

final class FontTests: XCTestCase {
    func testPlaypenSansIsRegistered() throws {
        XCTAssertTrue(FontRegistrar.registerAll())
        let font = try XCTUnwrap(UIFont(name: FontRegistrar.postScriptName, size: 30))
        XCTAssertEqual(font.familyName, FontRegistrar.familyName)
    }

    func testRegisterTwiceIsHarmless() {
        XCTAssertTrue(FontRegistrar.registerAll())
        XCTAssertTrue(FontRegistrar.registerAll())
    }

    func testWeightsResolve() throws {
        XCTAssertTrue(FontRegistrar.registerAll())
        let text = "Brush teeth" as NSString
        let widths = [UIFont.Weight.medium, .semibold, .bold].map { weight -> CGFloat in
            let font = FontRegistrar.font(size: 30, weight: weight)
            return text.size(withAttributes: [.font: font]).width
        }
        XCTAssertLessThan(widths[0], widths[1])
        XCTAssertLessThan(widths[1], widths[2])
    }
}
