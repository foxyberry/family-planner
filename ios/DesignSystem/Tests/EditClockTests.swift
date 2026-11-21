import DesignSystem
import XCTest

/// Board G1 on the edit clock, at board units: when two "+" overlap.
final class EditClockTests: XCTestCase {
    /// Drawn circles 44 across with centres 276 from the middle meet under about 37 minutes apart.
    func testTwoPlusOverlapWhenTheirDrawnCirclesMeet() {
        XCTAssertTrue(EditClock.addButtonsOverlap(1185, 1200), "a 15-minute shower")
        XCTAssertTrue(EditClock.addButtonsOverlap(1155, 1185), "30 minutes")
        XCTAssertTrue(EditClock.addButtonsOverlap(1100, 1136))
        XCTAssertFalse(EditClock.addButtonsOverlap(1100, 1137))
        XCTAssertFalse(EditClock.addButtonsOverlap(1155, 1200), "45 minutes")
        XCTAssertTrue(EditClock.addButtonsOverlap(1430, 10), "across midnight")
    }

    /// Only the earlier of two overlapping "+" shows: Dinner | Shower keeps it, Shower | Sleep not.
    func testOnlyTheEarlierPlusShows() {
        let buttons = [1200, 1110, 1185].enumerated().map { EditClock.AddBetween(knob: $0.offset, minute: $0.element) }
        XCTAssertEqual(EditClock.showing(buttons).map(\.minute), [1110, 1185])
    }

    /// Spec "Sizing → Touch", rule 2: a drag on a slice in the ring grabs the knob nearest by angle.
    func testADragInTheRingGrabsTheNearestKnob() {
        let knobs: [Double] = [390, 450, 900, 1110, 1155, 1200]
        XCTAssertEqual(EditClock.grabbedKnob(at: 1000, knobs: knobs), 2, "Snack's start is 100 away, Dinner's 110")
        XCTAssertEqual(EditClock.grabbedKnob(at: 1130, knobs: knobs), 3)
        XCTAssertEqual(EditClock.grabbedKnob(at: 60, knobs: knobs), 5, "across midnight: 8 pm is 300 away, 6:30 am 330")
        XCTAssertEqual(EditClock.grabbedKnob(at: 300, knobs: knobs), 0)
        XCTAssertEqual(EditClock.grabbedKnob(at: 0, knobs: [600]), 0, "alone: half of the whole way round")
        XCTAssertNil(EditClock.grabbedKnob(at: 0, knobs: []))
    }
}
