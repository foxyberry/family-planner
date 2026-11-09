import CrayonKit
import SwiftUI

/// The one primary action on a screen: black marker fill, white text, 96 tall. At night (spec
/// "Night mapping") it is a night control: the same shape with a `nightControl` fill, a chalk
/// marker outline and `nightText` label and arrow.
public struct InkButton: View {
    private let title: String
    private let arrow: Bool
    private let look: KidLook
    private let action: () -> Void

    /// `arrow`: a marker arrow 32 after the label, gap 12 ("Missions →").
    public init(_ title: String, arrow: Bool = false, look: KidLook = .day, action: @escaping () -> Void) {
        self.title = title
        self.arrow = arrow
        self.look = look
        self.action = action
    }

    private var label: Color { look == .day ? CrayonColor.card : CrayonColor.nightText }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Text(title).crayonType(.head)
                if arrow { MarkerIcon(.arrowRight, size: 32, color: label) }
            }
                .foregroundStyle(label)
                .padding(.horizontal, Spacing.l)
                .frame(maxWidth: .infinity, minHeight: 96)
                .modifier(Surface(look: look))
        }
        .buttonStyle(.plain)
    }

    private struct Surface: ViewModifier {
        let look: KidLook

        func body(content: Content) -> some View {
            if look == .day {
                content.partBackground(.roundedRect(cornerRadius: 24), fill: CrayonStyle.ink,
                                       seed: CrayonStyle.Seed.inkButton)
            } else {
                content.partBackground(.roundedRect(cornerRadius: 24), fill: .paper(CrayonColor.nightControl),
                                       seed: CrayonStyle.Seed.inkButton, markerColor: CrayonColor.chalk)
            }
        }
    }
}
