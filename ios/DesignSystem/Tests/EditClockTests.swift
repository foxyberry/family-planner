import DesignSystem
import XCTest

/// Board G1 on the edit clock, at board units: when two "+" touch and which ring each takes.
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

    /// The inner rings are smaller, so "+" there touch further apart: 46 and 62 minutes.
    func testInnerRingsTouchFurtherApart() {
        XCTAssertFalse(EditClock.addButtonsOverlap(1100, 1140, ring: 0), "40 minutes is free on the outer ring")
        XCTAssertTrue(EditClock.addButtonsOverlap(1100, 1140, ring: 1), "but touches on the middle one")
        XCTAssertFalse(EditClock.addButtonsOverlap(1100, 1147, ring: 1))
        XCTAssertTrue(EditClock.addButtonsOverlap(1100, 1161, ring: 2))
        XCTAssertFalse(EditClock.addButtonsOverlap(1100, 1162, ring: 2))
    }

    /// Spec "Add between two slices": each "+", in day order, takes the outermost free ring.
    func testPlusTakeTheOutermostFreeRing() {
        func rings(_ minutes: [Int]) -> [Int: Int] {
            let buttons = minutes.enumerated().map { EditClock.AddBetween(knob: $0.offset, minute: $0.element) }
            return Dictionary(uniqueKeysWithValues: EditClock.placed(buttons).map { ($0.minute, $0.ring) })
        }
        XCTAssertEqual(rings([1200, 1110, 1155]), [1110: 0, 1155: 0, 1200: 0], "45 minutes apart: one ring")
        XCTAssertEqual(rings([1155, 1185]), [1155: 0, 1185: 1], "a 30-minute item keeps both, on two rings")
        XCTAssertEqual(rings([1110, 1185, 1200]), [1110: 0, 1185: 0, 1200: 1], "a 15-minute shower")
        XCTAssertEqual(rings([1100, 1115, 1130]), [1100: 0, 1115: 1, 1130: 2], "three short slices: three rings")
        XCTAssertEqual(rings([1100, 1110, 1120, 1130]), [1100: 0, 1110: 1, 1120: 2],
                       "a fourth short slice in a row finds no free ring and hides")
        XCTAssertEqual(rings([1100, 1115, 1150]), [1100: 0, 1115: 1, 1150: 0],
                       "back to the outer ring once it is free again")
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
