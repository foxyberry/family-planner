import CrayonKit
import SwiftUI

/// A minutes stepper on a grown-up form (boards C2, C2c, S3): − 72, the value centred in 144, + 72,
/// then what the number means 16 after it (control 192: − 192–264, value 264–408, + 408–480, caption
/// 496 on the 13"), each × s. The buttons draw one inset
/// inside their frames, so a row of steppers takes `drawnRow()` like the other crayon rows. A − or +
/// at the value's limit draws the off look (`canMinus` / `canPlus` from the caller's State).
public struct MinutesStepper: View {
    @Environment(\.sizing) private var sizing
    private let value: String
    private let caption: String
    private let canMinus: Bool
    private let canPlus: Bool
    private let minus: () -> Void
    private let plus: () -> Void

    public init(value: String, caption: String, canMinus: Bool, canPlus: Bool,
                minus: @escaping () -> Void, plus: @escaping () -> Void) {
        self.value = value
        self.caption = caption
        self.canMinus = canMinus
        self.canPlus = canPlus
        self.minus = minus
        self.plus = plus
    }

    public var body: some View {
        HStack(spacing: 0) {
            RoundButton(glyph: .minus, action: minus).size(Self.button).enabled(canMinus)
            Text(value).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink)
                .frame(width: sizing.stepperValueWidth)
            RoundButton(glyph: .plus, action: plus).size(Self.button).enabled(canPlus)
            Text(caption).crayonType(.body).foregroundStyle(CrayonColor.softText).lineLimit(1)
                .padding(.leading, sizing(Spacing.s))
        }
    }

    /// The buttons' board size (72 × s on screen).
    static let button: CGFloat = 72

    /// A stepper row's frame height on this screen: its buttons' height.
    public static func rowHeight(_ sizing: Sizing) -> CGFloat { sizing(button) }
}
