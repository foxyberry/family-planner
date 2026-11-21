import CrayonKit
import KitArt
import SwiftUI

/// An 80 paper circle holding a symbol, a short text, a glyph (back, close, +) or a kit picture
/// (G0's pencil); 64 for C4's date paging. Board sizes, × s on screen. A tap hits only the drawn
/// circle, the frame less the part inset (spec "Sizing → Touch", rule 1, user 2026-11-22), so two
/// buttons whose frames meet never take each other's taps.
public struct RoundButton: View {
    private enum Content { case symbol(String), text(String), glyph(MarkerGlyph), picture(KitSlot) }
    private let content: Content
    private let action: () -> Void
    private var size: CGFloat = 80
    private var look: KidLook = .day
    @Environment(\.sizing) private var sizing
    /// The board diameter × s.
    private var drawn: CGFloat { sizing(size) }

    public init(systemImage: String, action: @escaping () -> Void) {
        content = .symbol(systemImage)
        self.action = action
    }

    /// A marker glyph at 40 (back chevron, plus, minus).
    public init(glyph: MarkerGlyph, action: @escaping () -> Void) {
        content = .glyph(glyph)
        self.action = action
    }

    /// A kit picture at 70 % of the circle (board G0: the pencil, 56 in 80).
    public init(picture: KitSlot, action: @escaping () -> Void) {
        content = .picture(picture)
        self.action = action
    }

    public init(text: String, action: @escaping () -> Void) {
        content = .text(text)
        self.action = action
    }

    /// The same button at another board diameter (board C4 paging: 64); the glyph keeps half of it.
    public func size(_ size: CGFloat) -> RoundButton {
        var copy = self
        copy.size = size
        return copy
    }

    /// Spec "Night mapping": at night a white round is a night control (`nightControl` fill, chalk
    /// outline); the kid homes' pencil uses it.
    public func look(_ look: KidLook) -> RoundButton {
        var copy = self
        copy.look = look
        return copy
    }

    public var body: some View {
        Button(action: action) {
            Group {
                switch content {
                case let .symbol(name): Image(systemName: name).font(CrayonType.head.font(sizing).weight(.bold))
                case let .text(text): Text(text).crayonType(.head)
                case let .glyph(glyph): MarkerIcon(glyph, size: drawn / 2)
                // A picture follows its circle by the board's ratio (G0: the pencil, 56 in 80).
                case let .picture(slot): KitIcon(slot, size: drawn * 0.7)
                }
            }
            .foregroundStyle(look == .day ? CrayonColor.ink : CrayonColor.nightText)
            .frame(width: drawn, height: drawn)
            .partBackground(.circle, fill: look == .day ? CrayonStyle.paper : .paper(CrayonColor.nightControl),
                            seed: CrayonStyle.Seed.roundButton,
                            markerColor: look == .day ? CrayonColor.outline : CrayonColor.chalk)
        }
        .buttonStyle(.plain)
    }
}
