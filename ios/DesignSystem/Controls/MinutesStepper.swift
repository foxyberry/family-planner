import CrayonKit
import SwiftUI

/// A minutes stepper on a grown-up form (boards C2, C2c, S3): − 72, the value centred in 144, + 72,
/// then what the number means 16 after it (control 192: − 192–264, value 264–408, + 408–480, caption
/// 496 on the 13"). The buttons draw one inset inside their frames, so a row of steppers takes
/// `drawnRow()` like the other crayon rows.
public struct MinutesStepper: View {
    public static let valueWidth: CGFloat = 144
    private let value: String
    private let caption: String
    private let spoken: String
    private let minus: () -> Void
    private let plus: () -> Void

    /// `spoken`: what VoiceOver calls both buttons ("Walk", "Ride on 34").
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
            RoundButton(glyph: .minus, accessibilityLabel: spoken, action: minus).size(72)
            Text(value).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink)
                .frame(width: Self.valueWidth)
            RoundButton(glyph: .plus, accessibilityLabel: spoken, action: plus).size(72)
            Text(caption).crayonType(.body).foregroundStyle(CrayonColor.softText).lineLimit(1)
                .padding(.leading, Spacing.s)
        }
    }
}
