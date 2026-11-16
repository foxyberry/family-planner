import CrayonKit
import SwiftUI

/// White paper with a marker edge and 24 pt corners; its content sits `cardPadding` inside.
public struct PaperCard<Content: View>: View {
    private let content: Content
    private let seed: UInt32
    private let padding: EdgeInsets?
    @Environment(\.cardPadding) private var environmentPadding

    /// `padding` replaces the environment's `cardPadding` (spec "Layout balance": a nested card
    /// pads `max(24 s, 16)`).
    public init(seed: UInt32 = 0, padding: EdgeInsets? = nil, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.seed = seed
        self.padding = padding
    }

    public var body: some View {
        content
            .padding(padding ?? environmentPadding)
            .partBackground(.roundedRect(cornerRadius: 24), fill: CrayonStyle.paper,
                              seed: CrayonStyle.Seed.card + seed)
    }
}
