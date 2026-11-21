import ComposableArchitecture
import CrayonKit
import DesignSystem
import KitArt
import Strings
import SwiftUI

/// G6f "+ Add a child": the S1 kid card (name, age, colour, face) on the grown-up frame; "Add"
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
            PaperCard(seed: 37) {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    ListRow(leading: L10n.tr("s1.name"), minHeight: 80) {
                        CrayonField(L10n.tr("s1.name.placeholder"), text: $store.name).frame(width: 400)
                    }
                    ListRow(leading: L10n.tr("s1.age"), minHeight: 80) {
                        CrayonField(L10n.tr("s1.age.placeholder"), text: $store.ageText)
                            .keyboardType(.numberPad)
                            .frame(width: 112)
                    }
                    ListRow(leading: L10n.tr("s1.colour"), minHeight: 80) {
                        HStack(spacing: Spacing.xs) {
                            ForEach(0..<AddChildFeature.colours, id: \.self) { colour in
                                ColourSwatch(colorIndex: colour, isPicked: store.colorIndex == colour,
                                             accessibilityLabel: AddChildFeature.State.colourName(colour)) {
                                    store.send(.colourTapped(colour))
                                }
                            }
                        }
                    }
                    ListRow(leading: L10n.tr("s1.face"), minHeight: 80) {
                        HStack(spacing: Spacing.sm) {
                            face(.kidGirl, label: L10n.tr("s1.face.girl"))
                            face(.kidBoy, label: L10n.tr("s1.face.boy"))
                        }
                    }
                }
                .frame(width: layout.editorRowsWidth, alignment: .leading)
            }
            .frame(width: layout.form.width, height: layout.form.height, alignment: .top)
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

    private func face(_ slot: KitSlot, label: String) -> some View {
        Button { store.send(.faceTapped(slot.rawValue)) } label: {
            KitIcon(slot, size: 56)
                .frame(width: 64, height: 64)
                .background { CrayonSurface(.circle, fill: CrayonStyle.paper, marker: .thin, seed: 1650) }
                .overlay {
                    if store.face == slot.rawValue {
                        Circle().stroke(CrayonColor.pickBlue, lineWidth: 5).frame(width: 72, height: 72)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(store.face == slot.rawValue ? .isSelected : [])
    }
}
