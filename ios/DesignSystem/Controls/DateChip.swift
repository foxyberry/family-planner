import CrayonKit
import SwiftUI

/// A date button (weekday over day number), 96 × 104; sky blue when on; `isToday` underlines the
/// number. Without a weekday it is G1c's square 68 × 68 chip with the number only (body bold): the
/// picker names the weekdays once, in a header row.
public struct DateChip: View {
    @Environment(\.sizing) private var sizing
    private let weekday: String?
    private let day: Int
    private let isOn: Bool
    private let isToday: Bool
    private let action: () -> Void

    /// The weekday over the number (E5's dates).
    public init(weekday: String, day: Int, isOn: Bool, isToday: Bool = false, action: @escaping () -> Void) {
        self.weekday = weekday
        self.day = day
        self.isOn = isOn
        self.isToday = isToday
        self.action = action
    }

    /// The number only (board G1c), under a weekday header row.
    public init(day: Int, isOn: Bool, isToday: Bool = false, action: @escaping () -> Void) {
        self.weekday = nil
        self.day = day
        self.isOn = isOn
        self.isToday = isToday
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                if let weekday {
                    Text(weekday).crayonType(.caption)
                    Text("\(day)").crayonType(.head).underline(isToday)
                } else {
                    Text("\(day)").crayonType(.body, bold: true).underline(isToday)
                }
            }
            .foregroundStyle(isOn ? CrayonColor.pictureInk : CrayonColor.ink)
            .frame(width: size.width, height: size.height)
            .partBackground(.roundedRect(cornerRadius: weekday == nil ? 14 : 24),
                            fill: isOn ? CrayonStyle.skyPill : CrayonStyle.paper, seed: CrayonStyle.Seed.dateChip)
        }
        .buttonStyle(.plain)
    }

    /// 96 × 104, or G1c's square 68 × 68.
    private var size: CGSize {
        weekday == nil ? CGSize(width: sizing(68), height: sizing(68)) : sizing.dateChip
    }
}
