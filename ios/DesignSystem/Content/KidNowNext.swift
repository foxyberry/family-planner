import CrayonKit
import KitArt
import Strings
import SwiftUI

/// The younger kid's day on the home screen (board A1): a big "now" picture and a smaller "next" one.
public struct KidNowNext: View {
    private let now: KitSlot
    private let next: KitSlot?
    private let look: KidLook
    @Environment(\.sizing) private var sizing

    /// Pictures are `KitSlot` raw values; an unknown name falls back to play. At night the captions
    /// use the night soft text (board A1n).
    public init(now: String, next: String?, look: KidLook = .day) {
        self.now = KitSlot(rawValue: now) ?? .actPlay
        self.next = next.map { KitSlot(rawValue: $0) ?? .actPlay }
        self.look = look
    }

    public var body: some View {
        // Boards A1/A1m: now 160 and next 104, bottoms aligned, 40 apart; sizes follow the screen.
        let s = sizing.s
        return HStack(alignment: .bottom, spacing: sizing.space(Spacing.l)) {
            circle(now, diameter: 160 * s, picture: 104 * s, fill: CrayonStyle.apricot, caption: L10n.tr("kid.now"),
                   seed: 3101)
            if let next {
                circle(next, diameter: 104 * s, picture: 64 * s, fill: CrayonStyle.paper, caption: L10n.tr("kid.next"),
                       seed: 3102)
            }
        }
    }

    private func circle(_ slot: KitSlot, diameter: CGFloat, picture: CGFloat, fill: CrayonFill, caption: String,
                        seed: UInt32) -> some View {
        VStack(spacing: Spacing.xs) {
            KitIcon(slot, size: picture)
                .frame(width: diameter, height: diameter)
                .crayonBackground(.circle, fill: fill, seed: seed)
            Text(caption).crayonType(.caption).foregroundStyle(look.softText)
        }
        .accessibilityElement(children: .combine)
    }
}
