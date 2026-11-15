import CoreGraphics
import SwiftUI
import UIKit

/// Spec "Sizing formulas → Part floors" (2026-11-15): one helper per part, so no screen sets its own
/// sizes. Every value is `max(board × s, floor)` (`fluid`), so on the 13" (s = 1) it is the board
/// value and a floor never changes the 13" look.
public extension Sizing {
    // MARK: Touch floors

    /// The smallest drawn grown-up control (its visible box is its touch box).
    static let grownupTouch: CGFloat = 48
    /// The smallest kid tap target.
    static let kidTouch: CGFloat = 72

    // MARK: Grown-up controls

    /// `CrayonField`, `FieldButton`: 80 tall on the board, never under 64.
    var fieldHeight: CGFloat { fluid(80, 64) }
    /// `TimeField`: 176 wide on the board, never under 142 ("12:45 pm" 110 + 2 × 16).
    var timeFieldWidth: CGFloat { fluid(176, 142) }
    static let timeFieldMinimum: CGFloat = 142
    /// `InkButton`: the main 96 never under 72, the form 80 never under 64, the 72 card button
    /// never under 56.
    func inkButtonHeight(_ board: CGFloat) -> CGFloat {
        board >= 96 ? fluid(board, 72) : board >= 80 ? fluid(board, 64) : fluid(board, 56)
    }
    /// `CrayonTabs`, `PillToggle`, `DayChip`: 72 on the board, never under 56.
    func tabHeight(_ board: CGFloat = 72) -> CGFloat { fluid(board, 56) }
    /// An equal-choice tab: the board width × s, never under its longest label + 2 × 16.
    func tabWidth(_ board: CGFloat, minimum: CGFloat) -> CGFloat { fluid(board, minimum) }
    /// S2 / G7 Goes to: 180, never under "Preschool" bold 117 + 32.
    var goesToTabWidth: CGFloat { tabWidth(180, minimum: 149) }
    /// `RoundButton`: the board diameter × s, never under 56 (or the board size when smaller).
    func roundButton(_ board: CGFloat) -> CGFloat { fluid(board, min(56, board)) }
    /// `CrayonSwitch`: 96 × 52 on the board, never under 72 × 48; knob 44, never under 40.
    var switchSize: CGSize { CGSize(width: fluid(96, 72), height: fluid(52, 48)) }
    var switchKnob: CGFloat { fluid(44, 40) }
    /// `SettingRow`: 120 tall, never under 88; its picture 56, never under 48.
    var settingRowHeight: CGFloat { fluid(120, 88) }
    var settingRowPicture: CGFloat { fluid(56, 48) }
    /// `ColourSwatch` 56 → 48; S1 faces 64 → 56.
    var swatch: CGFloat { fluid(56, 48) }
    var pickedFace: CGFloat { fluid(64, 56) }
    /// `ChoiceCircles`, `PictureRow`, `IconPicker` circles (88 / 104 / 112): never under 72.
    func pictureCircle(_ board: CGFloat) -> CGFloat { fluid(board, 72) }
    /// `DateChip` 96 wide, never under 72; its height keeps 104 : 96.
    var dateChip: CGSize { let width = fluid(96, 72); return CGSize(width: width, height: width * 104 / 96) }
    /// The clock "+" and the add-between button: 56, never under 48.
    var clockPlus: CGFloat { fluid(56, 48) }
    /// One-line search rows (keyboard up): 48 fixed.
    static let oneLineRow: CGFloat = 48
    /// Two-line rows: 72 fixed.
    static let twoLineRow: CGFloat = 72

    // MARK: Padding

    /// Text to a control's drawn edge: 24, never under 16.
    var textPadding: CGFloat { fluid(24, 16) }
    /// Form card inset: 40, never under 28.
    var formCardInset: CGFloat { fluid(40, 28) }
    /// Small cards (G1 slice card, `ConfirmCard`, list cards): 24, never under 16.
    var smallCardInset: CGFloat { fluid(24, 16) }
    /// Label → control gap and the gaps beside a joiner: 16, never under 12.
    var pairGap: CGFloat { fluid(16, 12) }
    /// The "→" joiner between paired controls: 40, never under 24.
    var joiner: CGFloat { fluid(40, 24) }

    // MARK: Kid controls

    /// Every kid tap target: the board size × s, never under 72.
    func kidTarget(_ board: CGFloat) -> CGFloat { fluid(board, Self.kidTouch) }
    /// Mission and check circles: 112, never under 88.
    var missionCircle: CGFloat { fluid(112, 88) }
    /// Pencil and sky switch: 96 tall, never under 72.
    var kidCornerControl: CGFloat { fluid(96, 72) }
    /// `TimeLeft` compact: 72, never under 56.
    var timeLeftCompact: CGFloat { fluid(72, 56) }

    // MARK: Rows that give way

    /// A start → end pair of time fields in `inner` points (spec "give way", worked example: the
    /// G1 slice card). Gaps and joiner start scaled; when the fields would be under 142 they drop to
    /// their floors; when that is still not enough the pair stacks ("→ end" on a second line).
    struct TimePair: Equatable, Sendable {
        public let field: CGFloat
        public let gap: CGFloat
        public let joiner: CGFloat
        public let stacked: Bool
    }

    func timePair(inner: CGFloat, board: CGFloat = 176) -> TimePair {
        func fields(gap: CGFloat, joiner: CGFloat) -> CGFloat { min(board, (inner - 2 * gap - joiner) / 2) }
        let scaled = fields(gap: pairGap, joiner: joiner)
        if scaled >= Self.timeFieldMinimum { return TimePair(field: scaled, gap: pairGap, joiner: joiner, stacked: false) }
        let tight = fields(gap: 12, joiner: 24)
        if tight >= Self.timeFieldMinimum { return TimePair(field: tight, gap: 12, joiner: 24, stacked: false) }
        return TimePair(field: max(Self.timeFieldMinimum, min(board, inner - 12 - 24)), gap: 12, joiner: 24, stacked: true)
    }

    /// A card's label column (spec "Label column"): its board column × s, or wider for its longest
    /// label (caption 24 bold) + 16. On the 13" the board column stays as drawn.
    func labelColumn(base: CGFloat, labels: [String]) -> CGFloat {
        guard s < 1 else { return base }
        let widest = labels.map { CrayonType.captionBoldWidth($0) }.max() ?? 0
        return max(base, ceil(widest) + 16)
    }
}

public extension EnvironmentValues {
    /// True on kid screens (`KidFullScreen`, `KidScreen`): controls take the kid touch floor (72).
    @Entry var isKidScreen = false
    /// How much `formLabels` widened the card's label column: controls sized from the layout's
    /// control column take this off.
    @Entry var formLabelExtra: CGFloat = 0
}

public extension CrayonType {
    /// The width of `text` in caption 24 bold (labels), measured in Playpen Sans.
    nonisolated static func captionBoldWidth(_ text: String) -> CGFloat {
        let font = FontRegistrar.font(size: 24, weight: .bold)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
}

private struct FormLabelsModifier: ViewModifier {
    let labels: [String]
    @Environment(\.sizing) private var sizing
    @Environment(\.formLabelWidth) private var base

    func body(content: Content) -> some View {
        let start = base ?? 128 * sizing.s
        let column = sizing.labelColumn(base: start, labels: labels)
        content.environment(\.formLabelWidth, column)
            .environment(\.formLabelExtra, column - start)
    }
}

public extension View {
    /// Spec "Label column": the card's label column fits its longest label (+ 16) on smaller iPads,
    /// so labels never shrink or wrap. Pass every label the card shows.
    func formLabels(_ labels: [String]) -> some View { modifier(FormLabelsModifier(labels: labels)) }
}
