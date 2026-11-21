import CrayonKit
import KitArt
import SwiftUI

/// The younger kid's day on the home screen (board A1): a big "now" picture and a smaller "next" one.
public struct KidNowNext: View {
    private let now: KitSlot
    private let next: KitSlot?
    private let look: KidLook
    @Environment(\.sizing) private var sizing

    private let nowCaption: String
    private let nextCaption: String

    /// The captions come from the caller's State ("Now", "Next"). At night they use the night soft
    /// text (board A1n).
    public init(now: KitSlot, next: KitSlot?, nowCaption: String, nextCaption: String, look: KidLook = .day) {
        self.now = now
        self.next = next
        self.nowCaption = nowCaption
        self.nextCaption = nextCaption
        self.look = look
    }

    public var body: some View {
        // Boards A1/A1m: now 160 and next 104, bottoms aligned, 40 apart; sizes follow the screen.
        let s = sizing.s
        return HStack(alignment: .bottom, spacing: sizing(Spacing.l)) {
            circle(now, diameter: 160 * s, picture: 104 * s, fill: CrayonStyle.apricot, caption: nowCaption,
                   seed: 3101)
            if let next {
                circle(next, diameter: 104 * s, picture: 64 * s, fill: CrayonStyle.paper, caption: nextCaption,
                       seed: 3102)
            }
        }
    }

    private func circle(_ slot: KitSlot, diameter: CGFloat, picture: CGFloat, fill: CrayonFill, caption: String,
                        seed: UInt32) -> some View {
        VStack(spacing: sizing(Spacing.xs)) {
            KitIcon(slot, size: picture)
                .frame(width: diameter, height: diameter)
                .crayonBackground(.circle, fill: fill, seed: seed)
            Text(caption).crayonType(.caption).foregroundStyle(look.softText)
        }
    }
}
