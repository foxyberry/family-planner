import CrayonKit
import Strings
import SwiftUI

/// The header of every grown-up screen (board 0f / C1 / C3 / C6): the crayon Back button, the title,
/// optional controls after it (kid tabs), and on the right "Grown-ups only" or a screen's own
/// control (C6: Undo, 1130–1312). During the relock countdown the right side reads "Locks in 0:30"
/// (`relockCaption`).
public struct GrownupHeader<Accessory: View, Trailing: View>: View {
    private let title: String
    private let caption: String
    private let onBack: () -> Void
    private let accessory: Accessory
    private let trailing: Trailing
    @Environment(\.relockCaption) private var relockCaption
    @Environment(\.sizing) private var sizing

    public init(title: String, caption: String = L10n.tr("grownup.caption"), onBack: @escaping () -> Void,
                @ViewBuilder accessory: () -> Accessory, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.caption = caption
        self.onBack = onBack
        self.accessory = accessory()
        self.trailing = trailing()
    }

    public var body: some View {
        // ← at 64, the title 24 after it (168), the right side ending on 1312 (GrownupLayout).
        HStack(spacing: GrownupLayout(sizing: sizing).titleGap) {
            RoundButton(glyph: .chevronLeft, accessibilityLabel: L10n.tr("grownup.back"), action: onBack)
            Text(title).crayonType(.title).foregroundStyle(CrayonColor.ink).lineLimit(1).layoutPriority(1)
            accessory
            Spacer(minLength: Spacing.m)
            if relockCaption == nil, Trailing.self != EmptyView.self {
                trailing
            } else {
                Text(relockCaption ?? caption).crayonType(.caption)
                    .foregroundStyle(relockCaption == nil ? CrayonColor.softText : CrayonColor.hurry)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}

extension GrownupHeader where Trailing == EmptyView {
    public init(title: String, caption: String = L10n.tr("grownup.caption"), onBack: @escaping () -> Void,
                @ViewBuilder accessory: () -> Accessory) {
        self.init(title: title, caption: caption, onBack: onBack, accessory: accessory) { EmptyView() }
    }
}

extension GrownupHeader where Accessory == EmptyView, Trailing == EmptyView {
    public init(title: String, caption: String = L10n.tr("grownup.caption"), onBack: @escaping () -> Void) {
        self.init(title: title, caption: caption, onBack: onBack) { EmptyView() }
    }
}
