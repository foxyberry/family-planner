import DesignSystem
import XCTest

/// Spec "Sizing formulas → Part floors" on every iPad the app checks. Expected values come from the
/// design skill's scale.py, not hand maths. This is the only check for the mini (no device here).
final class PartFloorsTests: XCTestCase {
    private let thirteen = Sizing(width: 1376, height: 1032)
    private let twelve = Sizing(width: 1366, height: 1024, safeTop: 32)
    private let eleven = Sizing(width: 1180, height: 820)
    private let mini = Sizing(width: 1133, height: 744)

    /// 13" is the board: every helper gives the board value back.
    func testThirteenInchIsTheBoard() {
        let s = thirteen
        XCTAssertEqual(s.fieldHeight, 80)
        XCTAssertEqual(s.timeFieldWidth, 176)
        XCTAssertEqual(s.inkButtonHeight(96), 96)
        XCTAssertEqual(s.inkButtonHeight(80), 80)
        XCTAssertEqual(s.inkButtonHeight(72), 72)
        XCTAssertEqual(s.tabHeight(), 72)
        XCTAssertEqual(s.goesToTabWidth, 180)
        XCTAssertEqual(s.roundButton(80), 80)
        XCTAssertEqual(s.roundButton(48), 48, "a board size under the floor stays as drawn")
        XCTAssertEqual(s.switchSize, CGSize(width: 96, height: 52))
        XCTAssertEqual(s.switchKnob, 44)
        XCTAssertEqual(s.settingRowHeight, 120)
        XCTAssertEqual(s.swatch, 56)
        XCTAssertEqual(s.pickedFace, 64)
        XCTAssertEqual(s.pictureCircle(88), 88)
        XCTAssertEqual(s.dateChip, CGSize(width: 96, height: 104))
        XCTAssertEqual(s.clockPlus, 56)
        XCTAssertEqual(s.textPadding, 24)
        XCTAssertEqual(s.smallCardInset, 24)
        XCTAssertEqual(s.kidTarget(96), 96)
        XCTAssertEqual(s.missionCircle, 112)
        XCTAssertEqual(s.kidCornerControl, 96)
        XCTAssertEqual(s.timeLeftCompact, 72)
    }

    /// Every control keeps its floor on every iPad (scale.py: 11" s 0.790, mini s 0.714).
    func testFloorsHoldOnSmallerIPads() {
        for s in [twelve, eleven, mini] {
            XCTAssertGreaterThanOrEqual(s.fieldHeight, 64)
            XCTAssertGreaterThanOrEqual(s.timeFieldWidth, 142)
            XCTAssertGreaterThanOrEqual(s.inkButtonHeight(96), 72)
            XCTAssertGreaterThanOrEqual(s.tabHeight(), 56)
            XCTAssertGreaterThanOrEqual(s.goesToTabWidth, 149)
            XCTAssertGreaterThanOrEqual(s.roundButton(72), 56)
            XCTAssertGreaterThanOrEqual(s.switchSize.height, Sizing.grownupTouch)
            XCTAssertGreaterThanOrEqual(s.swatch, Sizing.grownupTouch)
            XCTAssertGreaterThanOrEqual(s.pictureCircle(88), 72)
            XCTAssertGreaterThanOrEqual(s.clockPlus, Sizing.grownupTouch)
            XCTAssertGreaterThanOrEqual(s.kidTarget(64), Sizing.kidTouch)
            XCTAssertGreaterThanOrEqual(s.missionCircle, 88)
            XCTAssertGreaterThanOrEqual(s.kidCornerControl, Sizing.kidTouch)
            XCTAssertGreaterThanOrEqual(s.textPadding, 16)
        }
        XCTAssertEqual(eleven.timeFieldWidth, 142, accuracy: 0.1)
        XCTAssertEqual(eleven.goesToTabWidth, 149, accuracy: 0.1)
        // C3 Repeat: 180 × s on the 11" (about 142), never under "Monthly" bold + 32 (about 131).
        let repeats = ["Once", "Weekly", "Monthly"]
        XCTAssertEqual(thirteen.choiceTabWidth(180, labels: repeats), 180)
        XCTAssertEqual(eleven.choiceTabWidth(180, labels: repeats), 180 * eleven.s, accuracy: 0.1)
        XCTAssertGreaterThanOrEqual(mini.choiceTabWidth(180, labels: repeats),
                                    CrayonType.body.width("Monthly", sizing: mini, bold: true) + 32)
        XCTAssertEqual(eleven.choiceTabWidth(180, labels: ["A long kid name here"], faces: true),
                       40 + 8 + CrayonType.body.width("A long kid name here", sizing: eleven, bold: true) + 32,
                       accuracy: 0.1)
        XCTAssertEqual(eleven.missionCircle, 88.4, accuracy: 0.1)
        XCTAssertEqual(mini.fieldHeight, 64, accuracy: 0.1)
    }

    /// The worked example: the G1 slice card's start → end pair is 176 / ~143 / stacked.
    func testTheG1TimePairGivesWayInOrder() {
        func inner(_ s: Sizing) -> CGFloat { 472 * s.s - 2 * s.smallCardInset }
        let big = thirteen.timePair(inner: inner(thirteen))
        XCTAssertEqual(big.field, 176)
        XCTAssertEqual(big.gap, 16)
        XCTAssertEqual(big.joiner, 40)
        XCTAssertFalse(big.stacked)

        let eleventh = eleven.timePair(inner: inner(eleven))
        XCTAssertEqual(eleventh.field, 143.5, accuracy: 0.6)
        XCTAssertEqual(eleventh.gap, 12, "step 2: the gaps go to their floor")
        XCTAssertEqual(eleventh.joiner, 24)
        XCTAssertFalse(eleventh.stacked)

        let small = mini.timePair(inner: inner(mini))
        XCTAssertTrue(small.stacked, "step 5: the pair stacks on the mini")
        XCTAssertGreaterThanOrEqual(small.field, 142)
    }
}
