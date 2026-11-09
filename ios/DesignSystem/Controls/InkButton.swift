import CrayonKit
import SwiftUI

/// The one primary action on a screen: black marker fill, white text, 96 tall.
public struct InkButton: View {
    private let title: String
    private let arrow: Bool
    private let action: () -> Void

    /// `arrow`: a white marker arrow 32 after the label, gap 12 ("Missions →").
    public init(_ title: String, arrow: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.arrow = arrow
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Text(title).crayonType(.head)
                if arrow { MarkerIcon(.arrowRight, size: 32, color: CrayonColor.card) }
            }
                .foregroundStyle(CrayonColor.card)
                .padding(.horizontal, Spacing.l)
                .frame(maxWidth: .infinity, minHeight: 96)
                .partBackground(.roundedRect(cornerRadius: 24), fill: CrayonStyle.ink, seed: CrayonStyle.Seed.inkButton)
        }
        .buttonStyle(.plain)
    }
}
