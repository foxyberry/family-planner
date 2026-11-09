import CrayonKit
import SwiftUI

/// White paper with a marker edge and 24 pt corners; its content sits `cardInset` inside.
public struct PaperCard<Content: View>: View {
    private let content: Content
    private let seed: UInt32
    @Environment(\.cardInset) private var inset

    public init(seed: UInt32 = 0, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.seed = seed
    }

    public var body: some View {
        content
            .padding(inset)
            .partBackground(.roundedRect(cornerRadius: 24), fill: CrayonStyle.paper,
                              seed: CrayonStyle.Seed.card + seed)
    }
}
