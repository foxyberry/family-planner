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
    /// Spec S1 "Remove a kid": the corner × is drawn 48 and takes touches over 64.
    static let cornerControl: CGFloat = 48
    static let cornerControlTouch: CGFloat = 64
    static let timeFieldMinimum: CGFloat = 142
    /// `InkButton`: the main 96 never under 72, the form 80 never under 64, the 72 card button
    /// never under 56.
    func inkButtonHeight(_ board: CGFloat) -> CGFloat {
        board >= 96 ? fluid(board, 72) : board >= 80 ? fluid(board, 64) : fluid(board, 56)
    }
    /// Spec "Header row": every text control in a grown-up header is 72 tall on every iPad.
    static let headerControlHeight: CGFloat = 72
    /// `CrayonTabs`, `PillToggle`, `DayChip`: 72 on the board, never under 56.
    func tabHeight(_ board: CGFloat = 72) -> CGFloat { fluid(board, 56) }
    /// An equal-choice tab: the board width × s, never under its longest label + 2 × 16.
    func tabWidth(_ board: CGFloat, minimum: CGFloat) -> CGFloat { fluid(board, minimum) }
    /// Equal tabs in a labelled form row (C3 For / Repeat): the board width × s, never under the
    /// widest tab's content (a kid's face 40 + gap, then the bold label) + 2 × 16.
    func choiceTabWidth(_ board: CGFloat, labels: [String], faces: Bool = false) -> CGFloat {
        let face = faces ? Self.tabFace + Spacing.xs : 0  // KidFace.medium and its gap
        let content = labels.map { CrayonType.body.width($0, sizing: self, bold: true) }.max() ?? 0
        return tabWidth(board, minimum: face + content + 2 * Spacing.s)
    }
    /// The face inside a tab (`KidFace.medium`).
    static let tabFace: CGFloat = 40
    /// S2 / G7 Goes to: 180, never under "Preschool" bold 117 + 32.
    var goesToTabWidth: CGFloat { tabWidth(180, minimum: 149) }
    /// `RoundButton`: the board diameter × s, never under 56 (or the board size when smaller).
    func roundButton(_ board: CGFloat) -> CGFloat { fluid(board, min(56, board)) }
    /// `MinutesStepper`'s value column: 144 on the board, never under 112 ("90 min" bold fits).
    var stepperValueWidth: CGFloat { fluid(144, 112) }
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
    /// Nested cards (G1 slice card, list cards; spec "Layout balance"): 24, never under 16.
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
}

public extension EnvironmentValues {
    /// True on kid screens (`KidFullScreen`, `KidScreen`): controls take the kid touch floor (72).
    @Entry var isKidScreen = false
    /// True inside a grown-up header row: its text controls (tabs, pills) stay 72 on every iPad
    /// (spec "Part floors → Header row").
    @Entry var isHeaderRow = false
    /// Spec "Keyboard": the docked keyboard's top in window points while it is up, from the one
    /// keyboard client (AppFeature sets it at the root); nil when no keyboard counts as up.
    @Entry var keyboardTop: CGFloat? = nil
}

public extension CrayonType {
    /// The width of `text` in caption 24 bold (labels), measured in Playpen Sans.
    nonisolated static func captionBoldWidth(_ text: String) -> CGFloat {
        width(text, size: 24, bold: true)
    }

    /// The width of one line of `text` in this style on `sizing`, measured in Playpen Sans.
    nonisolated func width(_ text: String, sizing: Sizing, bold: Bool) -> CGFloat {
        Self.width(text, size: sizing.size(of: self), bold: bold)
    }

    nonisolated private static func width(_ text: String, size: CGFloat, bold: Bool) -> CGFloat {
        let font = FontRegistrar.font(size: size, weight: bold ? .bold : .medium)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
}

/// Spec "Part floors", text: a value line joined by " · " stays on one line when it fits, else wraps
/// at a separator onto at most 2 lines ("walk 10 min ·" / "ride 10 min"); it never clips mid-word.
public struct SeparatedValueText: View {
    private let parts: [String]
    private let type: CrayonType
    private let separator = " · " // copy-ok: a separator

    public init(_ text: String, type: CrayonType = .caption) {
        parts = text.components(separatedBy: " · ") // copy-ok: a separator
        self.type = type
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            Text(parts.joined(separator: separator)).crayonType(type).lineLimit(1).fixedSize()
            ForEach((1..<max(parts.count, 2)).reversed(), id: \.self) { split in
                VStack(alignment: .leading, spacing: 0) {
                    Text(parts.prefix(split).joined(separator: separator) + " ·").crayonType(type) // copy-ok: a separator
                        .lineLimit(1).fixedSize()
                    Text(parts.dropFirst(split).joined(separator: separator)).crayonType(type).lineLimit(1).fixedSize()
                }
            }
            Text(parts.joined(separator: separator)).crayonType(type).lineLimit(2)
        }
    }
}
