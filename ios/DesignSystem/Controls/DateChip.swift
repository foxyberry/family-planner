import CrayonKit
import SwiftUI

/// A date button (weekday over day number), 96 × 104; sky blue when on. `compact` is G1c's 70 × 84
/// chip; `isToday` underlines the number.
public struct DateChip: View {
    private let weekday: String
    private let day: Int
    private let isOn: Bool
    private let isToday: Bool
    private let compact: Bool
    private let action: () -> Void

    public init(weekday: String, day: Int, isOn: Bool, isToday: Bool = false, compact: Bool = false,
                action: @escaping () -> Void) {
        self.weekday = weekday
        self.day = day
        self.isOn = isOn
        self.isToday = isToday
        self.compact = compact
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Text(weekday).crayonType(.caption)
                Text("\(day)").crayonType(.head).underline(isToday)
            }
            .foregroundStyle(isOn ? CrayonColor.pictureInk : CrayonColor.ink)
            .frame(width: compact ? 70 : 96, height: compact ? 84 : 104)
            .partBackground(.roundedRect(cornerRadius: compact ? 14 : 24), fill: isOn ? CrayonStyle.skyPill : CrayonStyle.paper,
                              seed: CrayonStyle.Seed.dateChip)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
