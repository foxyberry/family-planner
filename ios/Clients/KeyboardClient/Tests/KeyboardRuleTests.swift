import CoreGraphics
import KeyboardClient
import XCTest

/// Spec "Keyboard": the three cases the size check lists, on an 11" window (1180 × 820).
final class KeyboardRuleTests: XCTestCase {
    private let window = CGRect(x: 0, y: 0, width: 1180, height: 820)

    func testADockedKeyboardIsUp() {
        let docked = CGRect(x: 0, y: 398, width: 1180, height: 422)
        XCTAssertEqual(KeyboardRule.keyboardTop(endFrame: docked, window: window), 398)
    }

    func testAFloatingOrSplitKeyboardCountsAsNone() {
        let floating = CGRect(x: 400, y: 300, width: 320, height: 260)
        XCTAssertNil(KeyboardRule.keyboardTop(endFrame: floating, window: window))
        let split = CGRect(x: 0, y: 420, width: 1180, height: 300) // not down to the bottom edge
        XCTAssertNil(KeyboardRule.keyboardTop(endFrame: split, window: window))
    }

    func testAHardwareKeyboardBarCountsAsNone() {
        let bar = CGRect(x: 0, y: 765, width: 1180, height: 55)
        XCTAssertNil(KeyboardRule.keyboardTop(endFrame: bar, window: window))
    }

    func testAHiddenKeyboardIsNone() {
        let gone = CGRect(x: 0, y: 820, width: 1180, height: 422)
        XCTAssertNil(KeyboardRule.keyboardTop(endFrame: gone, window: window))
        XCTAssertNil(KeyboardRule.keyboardTop(endFrame: .zero, window: window))
    }

    /// A window that does not start at the screen origin (iPadOS windows): measured from its own top.
    func testTopIsInWindowPoints() {
        let moved = CGRect(x: 0, y: 20, width: 1180, height: 800)
        let docked = CGRect(x: 0, y: 398, width: 1180, height: 422)
        XCTAssertEqual(KeyboardRule.keyboardTop(endFrame: docked, window: moved), 378)
    }
}
