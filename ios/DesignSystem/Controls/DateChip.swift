import CrayonKit
import SwiftUI

/// A date button (weekday over day number), 96 × 104; sky blue when on.
public struct DateChip: View {
    private let weekday: String
    private let day: Int
    private let isOn: Bool
    private let action: () -> Void

    public init(weekday: String, day: Int, isOn: Bool, action: @escaping () -> Void) {
        self.weekday = weekday
        self.day = day
        self.isOn = isOn
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(weekday).crayonType(.caption)
                Text("\(day)").crayonType(.head)
            }
            .foregroundStyle(CrayonColor.ink)
            .frame(width: 96, height: 104)
            .partBackground(.roundedRect(cornerRadius: 24), fill: isOn ? CrayonStyle.skyPill : CrayonStyle.paper,
                              seed: CrayonStyle.Seed.dateChip)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
