import ComposableArchitecture
import CrayonKit
import DesignSystem
import Domain
import KitArt
import Strings
import SwiftUI

/// C5 · Morning missions (board C5): the kid's missions in circle order, drag ≡ to reorder, tap a
/// row to rename it or change its picture.
public struct MissionEditorView: View {
    @Bindable var store: StoreOf<MissionEditorFeature>

    public init(store: StoreOf<MissionEditorFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            GrownupScreen {
                header
            } content: { layout in
                HStack(alignment: .top, spacing: layout.gap) {
                    // Board C5: the card runs 176–968 whatever the list's length.
                    PaperCard(seed: 41) { list.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading) }
                        .frame(width: layout.form.width, height: layout.form.height)
                    side.frame(width: layout.side.width, alignment: .topLeading)
                }
            } primaryAction: { layout in
                VStack(alignment: .trailing, spacing: Spacing.xs) {
                    InkButton(L10n.tr("c5.done")) { store.send(.doneTapped) }
                        .frame(width: layout.side.width)
                    if let error = store.saveError {
                        Text(error).crayonType(.caption).foregroundStyle(CrayonColor.lateText)
                    }
                }
            }
            if let draft = store.draft {
                CrayonColor.dim.ignoresSafeArea()
                    .onTapGesture { store.send(.draftClosed) }
                if let title = store.removeTitle {
                    ConfirmCard(title: title, message: nil, cancel: L10n.tr("c5.remove.keep"),
                                confirm: L10n.tr("c5.remove"), isDestructive: true,
                                onCancel: { store.send(.removeCancelled) }, onConfirm: { store.send(.removeConfirmed) })
                } else {
                    MissionDraftCard(draft: draft, onName: { store.send(.draftNameChanged($0)) },
                                     onPicture: { store.send(.draftPicturePicked($0)) },
                                     onDay: { store.send(.draftDayToggled($0)) },
                                     onRemove: { store.send(.removeTapped) }, onSave: { store.send(.saveTapped) })
                }
            }
        }
        .task { await store.send(.task).finish() }
    }

    private var header: some View {
        // Board C5: the kid tabs at the header's right end, in place of "Grown-ups only".
        GrownupHeader(title: L10n.tr("c5.title"), onBack: { store.send(.doneTapped) }, accessory: { EmptyView() }) {
            CrayonTabs(selection: Binding(get: { store.selectedKid }, set: { store.send(.kidTabTapped($0)) }),
                       items: store.kids.map { ($0.id, $0.name, KidFace.Badge(face: $0.face, colorIndex: $0.colorIndex)) },
                       itemSize: CGSize(width: 200, height: 72), spacing: Spacing.sm)
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(store.caption).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                .padding(.bottom, Spacing.s)
            // Layout v21: no divider lines inside cards; the rows are separated by space only.
            ForEach(Array(store.rows.enumerated()), id: \.element.id) { index, mission in
                row(mission, index: index)
            }
            if store.canAdd {
                Button { store.send(.addTapped) } label: {
                    HStack(spacing: Spacing.s) {
                        MarkerIcon(.plus, size: 28, color: CrayonColor.link)
                            .frame(width: 56, height: 56)
                            .crayonBackground(.circle, fill: nil, seed: 1801)
                        Text(store.addTitle).crayonType(.body).foregroundStyle(CrayonColor.link)
                    }
                    .frame(height: 72)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Text(L10n.tr("c5.most")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    .frame(height: 72)
            }
            GlyphText(L10n.tr("c5.footer"), glyph: .handle, color: CrayonColor.softText)
                .padding(.top, Spacing.s)
        }
    }

    private func row(_ mission: Mission, index: Int) -> some View {
        Button { store.send(.rowTapped(mission.id)) } label: {
            // Board C5: rows 88 tall; the handle, the picture, then the name on about 240.
            HStack(spacing: Spacing.m) {
                MarkerIcon(.handle, size: 32, color: CrayonColor.softText)
                KitIcon(KitSlot(iconName: mission.picture), size: 48)
                VStack(alignment: .leading, spacing: 0) {
                    Text(mission.name).crayonType(.body).foregroundStyle(CrayonColor.ink)
                    if let days = store.state.daysCaption(mission) {
                        Text(days).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    }
                }
                Spacer()
                MarkerIcon(.chevronRight, size: 28, color: CrayonColor.softText)
            }
            .frame(height: 88)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .draggable(mission.id.uuidString)
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first.flatMap(UUID.init(uuidString:)) else { return false }
            store.send(.moved(id, to: index))
            return true
        }
        .accessibilityAction(named: L10n.tr("c5.move_up")) { store.send(.moved(mission.id, to: index - 1)) }
        .accessibilityAction(named: L10n.tr("c5.move_down")) { store.send(.moved(mission.id, to: index + 1)) }
    }

    private var side: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if store.showsCardsNote {
                Text(store.kids.first { $0.id == store.selectedKid }?.name ?? "").crayonType(.head)
                    .foregroundStyle(CrayonColor.ink)
                Text(L10n.tr("c5.cards_note")).crayonType(.body).foregroundStyle(CrayonColor.ink)
            }
        }
    }
}
