import CrayonKit
import SwiftUI

/// An 80 pt paper circle holding a symbol or a short text (back, close, +).
public struct RoundButton: View {
    private enum Content { case symbol(String), text(String) }
    private let content: Content
    private let label: String
    private let action: () -> Void

    public init(systemImage: String, accessibilityLabel: String, action: @escaping () -> Void) {
        content = .symbol(systemImage)
        label = accessibilityLabel
        self.action = action
    }

    public init(text: String, accessibilityLabel: String, action: @escaping () -> Void) {
        content = .text(text)
        label = accessibilityLabel
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Group {
                switch content {
                case let .symbol(name): Image(systemName: name).font(CrayonType.head.font.weight(.bold))
                case let .text(text): Text(text).crayonType(.head)
                }
            }
            .foregroundStyle(CrayonColor.ink)
            .frame(width: 80, height: 80)
            .crayonBackground(.circle, fill: CrayonStyle.paper, seed: CrayonStyle.Seed.roundButton)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
