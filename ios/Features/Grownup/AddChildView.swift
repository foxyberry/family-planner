import ComposableArchitecture
import CrayonKit
import DesignSystem
import KitArt
import Strings
import SwiftUI

/// G6f "+ Add a child": the shared `KidCard` (name, age, colour, face) on the grown-up frame; "Add"
/// sits at the side column's foot.
public struct AddChildView: View {
    @Environment(\.sizing) private var sizing
    @Bindable var store: StoreOf<AddChildFeature>

    public init(store: StoreOf<AddChildFeature>) {
        self.store = store
    }

    public var body: some View {
        GrownupScreen(scrolls: false) {
            GrownupHeader(title: store.title, caption: store.headerCaption,
                          onBack: { store.send(.backTapped) })
        } content: { layout in
            // Spec "Kid card": the S1 card (two rows), hugging its rows at the top of the main slot.
            PaperCard(seed: 37, padding: sizing.cardPadding) {
                KidCard(words: store.cardWords, name: $store.name, age: $store.ageText, badge: store.badge,
                        colorIndex: store.colorIndex, face: store.face,
                        onColour: { store.send(.colourTapped($0)) }, onFace: { store.send(.faceTapped($0)) })
                    .formLines(KidCard.lines(layout, words: store.cardWords))
            }
            .frame(width: layout.form.width)
            .frame(height: layout.form.height, alignment: .top)
        } primaryAction: { layout in
            VStack(alignment: .leading, spacing: sizing(Spacing.xs)) {
                InkButton(L10n.tr("add_child.add")) { store.send(.saveTapped) }
                    .frame(width: layout.side.width)
                    .disabled(!store.canSave)
                if let error = store.saveError {
                    Text(error).crayonType(.caption).foregroundStyle(CrayonColor.lateText)
                }
            }
        }
    }
}
