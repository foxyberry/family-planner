import CrayonKit
import KitArt
import Strings
import SwiftUI

/// The step to do now, at least 104 tall; sky blue is reserved for this row.
/// Narrow rows follow the 0a rule "longer copy wraps, never shrinks": the title keeps its size and
/// wraps by word onto at most two lines (then "…"); below six grid columns the icon and tick step
/// down to the small sizes. Four columns is the narrowest supported width.
public struct NowRow: View {
    /// Below this width (six columns on the 12.9-inch screen) the row uses the small sizes.
    public static let compactBelow = GridMetrics(width: 1366).span(6)

    private let title: String
    private let icon: KitSlot
    private let isDone: Bool
    private let action: () -> Void

    public init(title: String, icon: KitSlot, isDone: Bool, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isDone = isDone
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            ViewThatFits(in: .horizontal) {
                // The ideal width is pinned so a long title never pushes a wide row into the small sizes.
                row(icon: 64, tick: 56, inset: 32)
                    .frame(minWidth: Self.compactBelow, idealWidth: Self.compactBelow, maxWidth: .infinity)
                row(icon: 56, tick: 48, inset: Spacing.m)
            }
            .crayonBackground(.roundedRect(cornerRadius: 24), fill: CrayonStyle.skyPill, seed: CrayonStyle.Seed.nowRow)
        }
        .buttonStyle(.plain)
        .accessibilityValue(isDone ? L10n.tr("check.done") : L10n.tr("check.not_done"))
    }

    private func row(icon iconSize: CGFloat, tick: CGFloat, inset: CGFloat) -> some View {
        HStack(spacing: Spacing.m) {
            KitIcon(icon, size: iconSize)
            Text(title).crayonType(.head)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            CheckMark(isDone: isDone, size: tick)
        }
        .foregroundStyle(CrayonColor.ink)
        .padding(.horizontal, inset)
        .padding(.vertical, Spacing.xs)
        .frame(minHeight: 104)
    }
}
