import CrayonKit
import SwiftUI

/// A weekday toggle (M T W ...), 72 pt circle; sky blue when on.
public struct DayChip: View {
    private let letter: String
    @Binding private var isOn: Bool

    public init(_ letter: String, isOn: Binding<Bool>) {
        self.letter = letter
        _isOn = isOn
    }

    public var body: some View {
        Button { isOn.toggle() } label: {
            Text(letter)
                .crayonType(.head)
                .foregroundStyle(CrayonColor.ink)
                .frame(width: 72, height: 72)
                .crayonBackground(.circle, fill: isOn ? CrayonStyle.skyPill : CrayonStyle.paper,
                                  seed: CrayonStyle.Seed.dayChip)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
