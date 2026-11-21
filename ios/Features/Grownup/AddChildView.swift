import ComposableArchitecture
import CrayonKit
import DesignSystem
import KitArt
import Strings
import SwiftUI

/// G6f "+ Add a child": the shared `KidCard` (name, age, colour, face) on the grown-up frame; "Add"
/// sits at the side column's foot.
public struct AddChildView: View {
    @Bindable var store: StoreOf<AddChildFeature>

    public init(store: StoreOf<AddChildFeature>) {
        self.store = store
    }

    public var body: some View {
        GrownupScreen(scrolls: false) {
            GrownupHeader(title: store.title, caption: store.headerCaption, backLabel: store.backLabel,
                          onBack: { store.send(.backTapped) })
        } content: { layout in
            // Spec "Kid card" (layout v59): the S1 card, hugging its four rows at the top of the main slot.
            PaperCard(seed: 37, padding: FormLines.cardPadding) {
                KidCard(words: store.cardWords, name: $store.name, age: $store.ageText, badge: store.badge,
                        shownName: store.trimmedName, colorIndex: store.colorIndex, face: store.face,
                        onColour: { store.send(.colourTapped($0)) }, onFace: { store.send(.faceTapped($0)) })
                    .formLines(layout.formLines())
            }
            .frame(width: layout.form.width)
            .frame(height: layout.form.height, alignment: .top)
        } primaryAction: { layout in
            VStack(alignment: .leading, spacing: Spacing.xs) {
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
