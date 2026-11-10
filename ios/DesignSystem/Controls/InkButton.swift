import CrayonKit
import SwiftUI

/// The one primary action on a screen: black marker fill, white text, 96 tall. At night (spec
/// "Night mapping") it is a night control: the same shape with a `nightControl` fill, a chalk
/// marker outline and `nightText` label and arrow.
public struct InkButton: View {
    private let title: String
    private let arrow: Bool
    private let look: KidLook
    private let height: CGFloat
    private let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    /// `arrow`: a marker arrow 32 after the label, gap 12 ("Missions →"). `height`: 80 on form cards.
    public init(_ title: String, arrow: Bool = false, look: KidLook = .day, height: CGFloat = 96,
                action: @escaping () -> Void) {
        self.title = title
        self.arrow = arrow
        self.look = look
        self.height = height
        self.action = action
    }

    /// Night controls at night on kid screens and in dark mode on grown-up screens.
    private var isNight: Bool { look == .night || colorScheme == .dark }
    private var label: Color { isNight ? CrayonColor.nightText : CrayonColor.card }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                Text(title).crayonType(.head)
                if arrow { MarkerIcon(.arrowRight, size: 32, color: label) }
            }
                .foregroundStyle(label)
                .padding(.horizontal, Spacing.l)
                .frame(maxWidth: .infinity, minHeight: height)
                .modifier(Surface(isNight: isNight))
        }
        .buttonStyle(.plain)
    }

    private struct Surface: ViewModifier {
        let isNight: Bool

        func body(content: Content) -> some View {
            if !isNight {
                content.partBackground(.roundedRect(cornerRadius: 24), fill: CrayonStyle.ink,
                                       seed: CrayonStyle.Seed.inkButton)
            } else {
                content.partBackground(.roundedRect(cornerRadius: 24), fill: .paper(CrayonColor.nightControl),
                                       seed: CrayonStyle.Seed.inkButton, markerColor: CrayonColor.chalk)
            }
        }
    }
}
