import CrayonKit
import SwiftUI

/// White paper with a marker edge and 24 pt corners; its content sits `cardInset` inside.
public struct PaperCard<Content: View>: View {
    private let content: Content
    private let seed: UInt32
    private let trailingInset: CGFloat?
    @Environment(\.cardInset) private var inset

    /// `trailingInset` replaces `cardInset` on the right only (the editor boards' rows end 22 in).
    public init(seed: UInt32 = 0, trailingInset: CGFloat? = nil, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.seed = seed
        self.trailingInset = trailingInset
    }

    public var body: some View {
        content
            .padding(EdgeInsets(top: inset, leading: inset, bottom: inset, trailing: trailingInset ?? inset))
            .partBackground(.roundedRect(cornerRadius: 24), fill: CrayonStyle.paper,
                              seed: CrayonStyle.Seed.card + seed)
    }
}
