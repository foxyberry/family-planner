import SwiftUI

/// The header of every grown-up screen (board 0f / C1 / C3): the crayon Back button, the title,
/// optional controls after it (kid tabs), and "Grown-ups only" on the right. During the relock
/// countdown the caption turns into "Locks in 0:30" (`relockCaption`).
public struct GrownupHeader<Accessory: View>: View {
    private let title: String
    private let caption: String
    private let onBack: () -> Void
    private let accessory: Accessory
    @Environment(\.relockCaption) private var relockCaption

    public init(title: String, caption: String = "Grown-ups only", onBack: @escaping () -> Void,
                @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.caption = caption
        self.onBack = onBack
        self.accessory = accessory()
    }

    public var body: some View {
        HStack(spacing: Spacing.m) {
            RoundButton(systemImage: "chevron.left", accessibilityLabel: "Back", action: onBack)
            Text(title).crayonType(.title).foregroundStyle(CrayonColor.ink).lineLimit(1)
            accessory
            Spacer(minLength: Spacing.m)
            Text(relockCaption ?? caption).crayonType(.caption)
                .foregroundStyle(relockCaption == nil ? CrayonColor.softText : CrayonColor.hurry)
                .lineLimit(1)
                .fixedSize()
        }
    }
}

extension GrownupHeader where Accessory == EmptyView {
    public init(title: String, caption: String = "Grown-ups only", onBack: @escaping () -> Void) {
        self.init(title: title, caption: caption, onBack: onBack) { EmptyView() }
    }
}
