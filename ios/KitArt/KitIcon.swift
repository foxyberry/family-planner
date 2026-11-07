import SwiftUI

/// A crayon picture for a slot at a square size (design sizes: 56, 64, 88, 104).
/// Screens use this instead of naming image assets, so a slot's picture can change later.
public struct KitIcon: View {
    private let slot: KitSlot
    private let size: CGFloat
    @Environment(\.kitArt) private var art

    public init(_ slot: KitSlot, size: CGFloat) {
        self.slot = slot
        self.size = size
    }

    public var body: some View {
        art.image(for: slot)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
