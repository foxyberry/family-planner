import CrayonKit
import SwiftUI

/// An 80 pt paper circle holding a symbol or a short text (back, close, +); 64 for C4's date paging.
public struct RoundButton: View {
    private enum Content { case symbol(String), text(String), glyph(MarkerGlyph) }
    private let content: Content
    private let label: String
    private let action: () -> Void
    private var size: CGFloat = 80

    public init(systemImage: String, accessibilityLabel: String, action: @escaping () -> Void) {
        content = .symbol(systemImage)
        label = accessibilityLabel
        self.action = action
    }

    /// A marker glyph at 40 (back chevron, plus, minus).
    public init(glyph: MarkerGlyph, accessibilityLabel: String, action: @escaping () -> Void) {
        content = .glyph(glyph)
        label = accessibilityLabel
        self.action = action
    }

    public init(text: String, accessibilityLabel: String, action: @escaping () -> Void) {
        content = .text(text)
        label = accessibilityLabel
        self.action = action
    }

    /// The same button at another diameter (board C4 paging: 64); the glyph keeps half of it.
    public func size(_ size: CGFloat) -> RoundButton {
        var copy = self
        copy.size = size
        return copy
    }

    public var body: some View {
        Button(action: action) {
            Group {
                switch content {
                case let .symbol(name): Image(systemName: name).font(CrayonType.head.font.weight(.bold))
                case let .text(text): Text(text).crayonType(.head)
                case let .glyph(glyph): MarkerIcon(glyph, size: size / 2)
                }
            }
            .foregroundStyle(CrayonColor.ink)
            .frame(width: size, height: size)
            .crayonBackground(.circle, fill: CrayonStyle.paper, seed: CrayonStyle.Seed.roundButton)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
