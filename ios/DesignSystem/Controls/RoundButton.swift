import CrayonKit
import KitArt
import SwiftUI

/// An 80 pt paper circle holding a symbol, a short text, a glyph (back, close, +) or a kit picture
/// (G0's pencil); 64 for C4's date paging.
public struct RoundButton: View {
    private enum Content { case symbol(String), text(String), glyph(MarkerGlyph), picture(KitSlot) }
    private let content: Content
    private let label: String
    private let action: () -> Void
    private var size: CGFloat = 80
    private var floor: CGFloat?
    private var touch: CGFloat?
    private var look: KidLook = .day
    @Environment(\.sizing) private var sizing
    @Environment(\.isKidScreen) private var isKidScreen
    /// Spec "Part floors": the board diameter × s, never under 56 (72 on kid screens), or under
    /// `floor` when one is set (the clock "+": 48).
    private var drawn: CGFloat {
        if let floor { return max(size * sizing.s, floor) }
        return isKidScreen ? sizing.kidTarget(size) : sizing.roundButton(size)
    }

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

    /// A kit picture at 70 % of the circle (board G0: the pencil, 56 in 80).
    public init(picture: KitSlot, accessibilityLabel: String, action: @escaping () -> Void) {
        content = .picture(picture)
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

    /// The smallest this button may be drawn on a smaller iPad, when its part has its own floor.
    public func floor(_ floor: CGFloat) -> RoundButton {
        var copy = self
        copy.floor = floor
        return copy
    }

    /// A touch area larger than the circle (S1's × : 48 drawn, touch 64). It reaches outside the
    /// frame, so the frame stays on its line (spec "Layout model": touch outside, invisible).
    public func touch(_ touch: CGFloat) -> RoundButton {
        var copy = self
        copy.touch = touch
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
                case let .symbol(name): Image(systemName: name).font(CrayonType.head.font.weight(.bold))
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
            .contentShape(Rectangle().inset(by: -max(0, ((touch ?? drawn) - drawn) / 2)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
