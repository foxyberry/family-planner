import DesignSystem
import XCTest

final class SlideToGoModelTests: XCTestCase {
    func testLockedIgnoresDrag() {
        var model = SlideToGoModel(phase: .locked(remaining: 3))
        model.dragChanged(progress: 0.5)
        XCTAssertEqual(model.phase, .locked(remaining: 3))
        XCTAssertFalse(model.dragEnded())
    }

    func testDragClampsToUnitRange() {
        var model = SlideToGoModel(phase: .idle)
        model.dragChanged(progress: 1.7)
        XCTAssertEqual(model.phase, .dragging(progress: 1))
        model.dragChanged(progress: -0.3)
        XCTAssertEqual(model.phase, .dragging(progress: 0))
    }

    func testReleaseBelowThresholdSnapsBack() {
        var model = SlideToGoModel(phase: .idle)
        model.dragChanged(progress: 0.6)
        XCTAssertFalse(model.dragEnded())
        XCTAssertEqual(model.phase, .idle)
    }

    func testReleaseAtThresholdCompletes() {
        var model = SlideToGoModel(phase: .idle)
        model.dragChanged(progress: SlideToGoModel.completeThreshold)
        XCTAssertTrue(model.dragEnded())
        XCTAssertEqual(model.phase, .done)
    }

    func testDoneIgnoresFurtherDrags() {
        var model = SlideToGoModel(phase: .done)
        model.dragChanged(progress: 0.2)
        XCTAssertEqual(model.phase, .done)
        XCTAssertFalse(model.dragEnded())
    }
}
