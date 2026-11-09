import CrayonKit
import SwiftUI

/// A weekday toggle (M T W ...), 72 pt circle; sky blue when on, its letter bold only when on.
/// `size` 56 for the read-only rows of C1/E6 (letters at caption size).
public struct DayChip: View {
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
                .foregroundStyle(CrayonColor.ink)
                .frame(width: size, height: size)
                .crayonBackground(.circle, fill: isOn ? CrayonStyle.skyPill : CrayonStyle.paper,
                                  seed: CrayonStyle.Seed.dayChip)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
