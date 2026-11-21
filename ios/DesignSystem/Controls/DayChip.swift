import CrayonKit
import SwiftUI

/// A weekday toggle (M T W ...), 72 pt circle; sky blue when on, its letter bold only when on.
/// `size` 56 for the read-only rows of C1/E6 (letters at caption size).
public struct DayChip: View {
    @Environment(\.sizing) private var sizing
    private var drawn: CGFloat { size >= 72 ? sizing.tabHeight(size) : size }
    private let letter: String
    private let size: CGFloat
    @Binding private var isOn: Bool

    public init(_ letter: String, isOn: Binding<Bool>, size: CGFloat = 72) {
        self.letter = letter
        self.size = size
        _isOn = isOn
    }

    public var body: some View {
        Button { isOn.toggle() } label: {
            Text(letter)
                .crayonType(size < 72 ? .caption : .head, bold: isOn)
                .foregroundStyle(isOn ? CrayonColor.pictureInk : CrayonColor.ink)
                // Spec "Part floors": the 72 chip is 72 × s, never under 56.
                .frame(width: drawn, height: drawn)
                .partBackground(.circle, fill: isOn ? CrayonStyle.skyPill : CrayonStyle.paper,
                                  seed: CrayonStyle.Seed.dayChip)
        }
        .buttonStyle(.plain)
    }
}
