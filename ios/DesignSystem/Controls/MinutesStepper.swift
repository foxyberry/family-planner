import CrayonKit
import SwiftUI

/// A minutes stepper on a grown-up form (boards C2, C2c, S3): − 72, the value centred in 144, + 72,
/// then what the number means 16 after it (control 192: − 192–264, value 264–408, + 408–480, caption
/// 496 on the 13"). Every size follows the iPad (spec "Part floors"). The buttons draw one inset
/// inside their frames, so a row of steppers takes `drawnRow()` like the other crayon rows.
/// VoiceOver reads one adjustable element: the label, the value and the caption; swipe up or down.
public struct MinutesStepper: View {
    @Environment(\.sizing) private var sizing
    private let value: String
    private let caption: String
    private let spoken: String
    private let minus: () -> Void
    private let plus: () -> Void

    /// `spoken`: what VoiceOver calls the stepper ("Walk", "Ride on 34").
    public init(value: String, caption: String, spoken: String, minus: @escaping () -> Void,
                plus: @escaping () -> Void) {
        self.value = value
        self.caption = caption
        self.spoken = spoken
        self.minus = minus
        self.plus = plus
    }

    public var body: some View {
        HStack(spacing: 0) {
            RoundButton(glyph: .minus, accessibilityLabel: spoken, action: minus).size(Self.button)
            Text(value).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink)
                .frame(width: sizing.stepperValueWidth)
            RoundButton(glyph: .plus, accessibilityLabel: spoken, action: plus).size(Self.button)
            Text(caption).crayonType(.body).foregroundStyle(CrayonColor.softText).lineLimit(1)
                .padding(.leading, sizing.space(Spacing.s))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
        .accessibilityValue(value)
        .accessibilityHint(caption)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: plus()
            case .decrement: minus()
            @unknown default: break
            }
        }
    }

    /// The buttons' board size; on screen `Sizing.roundButton(72)` (72 × s, never under 56).
    static let button: CGFloat = 72

    /// A stepper row's frame height on this iPad: its buttons' height.
    public static func rowHeight(_ sizing: Sizing) -> CGFloat { sizing.roundButton(button) }
}
