import CrayonKit
import SwiftUI

/// The one primary action on a screen: black marker fill, white text, 96 tall, corner 26 at every
/// width (board art `rr(6, 6, w − 12, h − 12, 26)`). At night (spec
/// "Night mapping") it is a night control: the same shape with a `nightControl` fill, a chalk
/// marker outline and `nightText` label and arrow. Off (`isEnabled: false`, a Save with nothing to
/// save yet) it draws at 40 % and takes no taps.
public struct InkButton: View {
    private let title: String
    private let arrow: Bool
    private let look: KidLook
    private let height: CGFloat
    private let isEnabled: Bool
    private let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.sizing) private var sizing

    /// `arrow`: a marker arrow 32 after the label, gap 12 ("Missions →"). `height`: the board height,
    /// 80 on form cards. `isEnabled`: the caller's State says whether the action can run now.
    public init(_ title: String, arrow: Bool = false, look: KidLook = .day, height: CGFloat = 96,
                isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.arrow = arrow
        self.look = look
        self.height = height
        self.isEnabled = isEnabled
        self.action = action
    }

    /// Night controls at night on kid screens and in dark mode on grown-up screens.
    private var isNight: Bool { look == .night || colorScheme == .dark }
    private var label: Color { isNight ? CrayonColor.nightText : CrayonColor.card }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: sizing(Spacing.sm)) {
                Text(title).crayonType(.head)
                if arrow { MarkerIcon(.arrowRight, size: sizing(32), color: label) }
            }
                .foregroundStyle(label)
                .padding(.horizontal, sizing(Spacing.l))
                // The board height (96, 80 on form cards) × s.
                .frame(maxWidth: .infinity, minHeight: sizing(height))
                .modifier(Surface(isNight: isNight))
        }
        .crayonPlain(isEnabled)
        // Off: the whole button at 40 % (the dimmed Save on S1–S4, the editors and the mission card).
        .offLook(isEnabled)
    }

    private struct Surface: ViewModifier {
        let isNight: Bool

        func body(content: Content) -> some View {
            if !isNight {
                content.partBackground(.roundedRect(cornerRadius: 26), fill: CrayonStyle.ink,
                                       seed: CrayonStyle.Seed.inkButton)
            } else {
                content.partBackground(.roundedRect(cornerRadius: 26), fill: .paper(CrayonColor.nightControl),
                                       seed: CrayonStyle.Seed.inkButton, markerColor: CrayonColor.chalk)
            }
        }
    }
}
