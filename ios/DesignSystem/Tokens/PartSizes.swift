import CoreGraphics
import SwiftUI
import UIKit

/// Spec "Layout model → Parts": each part owns its board size, scaled by s like everything else
/// (spec "Sizing: one scale, no floors"). One name per part size, so the board number lives in one
/// place; a size that is used once is written at its part as `sizing(board)`.
public extension Sizing {
    // MARK: Grown-up controls

    /// `CrayonField`, `FieldButton`: 80 tall.
    var fieldHeight: CGFloat { 80 * s }
    /// `TimeField`: 176 wide.
    var timeFieldWidth: CGFloat { 176 * s }
    /// Spec S1 "Remove a kid": the corner ×, 48 on the board (a `RoundButton` size); its touch area
    /// is the drawn circle.
    static let cornerControl: CGFloat = 48
    /// `CrayonTabs`, `PillToggle`, `DayChip`: 72 on the board (or the part's own board height).
    func tabHeight(_ board: CGFloat = 72) -> CGFloat { board * s }
    /// `MinutesStepper`'s value column: 144.
    var stepperValueWidth: CGFloat { 144 * s }
    /// `CrayonSwitch`: 96 × 52, knob 44.
    var switchSize: CGSize { CGSize(width: 96 * s, height: 52 * s) }
    var switchKnob: CGFloat { 44 * s }
    /// `SettingRow`: 120 tall, its picture 56.
    var settingRowHeight: CGFloat { 120 * s }
    var settingRowPicture: CGFloat { 56 * s }
    /// `ColourSwatch` 56; S1 faces 64.
    var swatch: CGFloat { 56 * s }
    var pickedFace: CGFloat { 64 * s }
    /// `DateChip` 96 × 104.
    var dateChip: CGSize { CGSize(width: 96 * s, height: 104 * s) }
    /// One-line search rows 48 (S2s with the keyboard up, design session 2026-11-15: one line,
    /// "{name} · {caption}"); two-line rows 72.
    var oneLineRow: CGFloat { 48 * s }
    var twoLineRow: CGFloat { 72 * s }

    // MARK: Padding

    /// Text to a control's drawn edge: 24.
    var textPadding: CGFloat { 24 * s }
    /// Nested cards (G1 slice card, list cards; spec "Layout balance"): 24.
    var smallCardInset: CGFloat { 24 * s }
    /// Label → control gap and the gaps beside a joiner: 16.
    var pairGap: CGFloat { 16 * s }
    /// The "→" joiner between paired controls: 40.
    var joiner: CGFloat { 40 * s }

    // MARK: Kid controls

    /// Mission and check circles: 112.
    var missionCircle: CGFloat { 112 * s }
    /// Pencil and sky switch: 96 tall.
    var kidCornerControl: CGFloat { 96 * s }
    /// `TimeLeft` compact: 72.
    var timeLeftCompact: CGFloat { 72 * s }
}

public extension EnvironmentValues {
    /// Spec "Keyboard": the docked keyboard's top in window points while it is up, from the one
    /// keyboard client (AppFeature sets it at the root); nil when no keyboard counts as up.
    @Entry var keyboardTop: CGFloat? = nil
}

public extension CrayonType {
    /// The width of `text` in caption 24 bold (labels) on the board, measured in Playpen Sans.
    nonisolated static func captionBoldWidth(_ text: String) -> CGFloat {
        width(text, size: CrayonType.caption.size, bold: true)
    }

    /// The width of one line of `text` in this style on `sizing`: measured at the board size, × s.
    nonisolated func width(_ text: String, sizing: Sizing, bold: Bool) -> CGFloat {
        Self.width(text, size: size, bold: bold) * sizing.s
    }

    nonisolated private static func width(_ text: String, size: CGFloat, bold: Bool) -> CGFloat {
        let font = FontRegistrar.font(size: size, weight: bold ? .bold : .medium)
        return ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
}
