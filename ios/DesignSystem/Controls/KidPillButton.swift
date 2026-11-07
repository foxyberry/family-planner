import CrayonKit
import KitArt
import SwiftUI

/// A child's choice button: apricot crayon pill, optional picture, 96 tall.
public struct KidPillButton: View {
    private let title: String
    private let icon: KitSlot?
    private let action: () -> Void

    public init(_ title: String, icon: KitSlot?, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                if let icon { KitIcon(icon, size: 56) }
                Text(title).crayonType(.head)
            }
            .foregroundStyle(CrayonColor.ink)
            .padding(.horizontal, Spacing.l)
            .frame(minHeight: 96)
            .crayonBackground(.capsule, fill: CrayonStyle.apricot, seed: CrayonStyle.Seed.kidPill)
        }
        .buttonStyle(.plain)
    }
}
