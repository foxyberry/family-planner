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
    @Environment(\.sizing) private var sizing
    @Bindable var store: StoreOf<MissionEditorFeature>

    public init(store: StoreOf<MissionEditorFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            // Spec "Scrolling": the card stays put and its rows scroll inside it.
            GrownupScreen(scrolls: false) {
                header
            } content: { layout in
                HStack(alignment: .top, spacing: layout.gap) {
                    // Board C5: the card runs 148–968 whatever the list's length.
                    PaperCard(seed: 41) {
                        ScrollColumn { list.frame(maxWidth: .infinity, alignment: .topLeading) }
                    }
                    .frame(width: layout.form.width, height: layout.form.height)
                    ScrollColumn { side }
                        .frame(width: layout.side.width, height: layout.action.minY - layout.side.minY - sizing(Spacing.s),
                               alignment: .topLeading)
                }
            } primaryAction: { layout in
                VStack(alignment: .trailing, spacing: sizing(Spacing.xs)) {
                    InkButton(store.doneTitle) { store.send(.doneTapped) }
                        .frame(width: layout.side.width)
                    if let error = store.saveError {
                        Text(error).crayonType(.caption).foregroundStyle(CrayonColor.lateText)
                    }
                }
            }
            if let draft = store.draft {
                CrayonColor.dim.fullBleed()
                    .onTapGesture { store.send(.draftClosed) }
                if let title = store.removeTitle {
                    ConfirmCard(title: title, message: nil, cancel: store.keepLabel,
                                confirm: store.removeLabel, isDestructive: true,
                                onCancel: { store.send(.removeCancelled) }, onConfirm: { store.send(.removeConfirmed) })
                } else {
                    MissionDraftCard(draft: draft, nameLabel: store.nameLabel, removeLabel: store.removeLabel,
                                     saveTitle: store.saveTitle, onName: { store.send(.draftNameChanged($0)) },
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
        GrownupHeader(title: store.title, caption: store.headerCaption,
                      onBack: { store.send(.doneTapped) }, accessory: { EmptyView() }) {
            CrayonTabs(selection: Binding(get: { store.selectedKid }, set: { store.send(.kidTabTapped($0)) }),
                       items: store.kids.map { ($0.id, $0.name, KidFace.Badge(face: $0.face, colorIndex: $0.colorIndex)) },
                       itemSize: CGSize(width: 200, height: 72), spacing: Spacing.sm)
        }
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Layout v21: no divider lines inside cards; the rows are separated by space only.
            ForEach(Array(store.rows.enumerated()), id: \.element.id) { index, mission in
                row(mission, index: index)
            }
            if store.canAdd {
                Button { store.send(.addTapped) } label: {
                    HStack(spacing: sizing(Spacing.s)) {
                        MarkerIcon(.plus, size: sizing(28), color: CrayonColor.link)
                            .frame(width: sizing(56), height: sizing(56))
                            .crayonBackground(.circle, fill: nil, seed: 1801)
                        Text(store.addTitle).crayonType(.body).foregroundStyle(CrayonColor.link)
                    }
                    .frame(height: sizing(72))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Text(store.mostCaption).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    .frame(height: sizing(72))
            }
        }
    }

    private func row(_ mission: Mission, index: Int) -> some View {
        Button { store.send(.rowTapped(mission.id)) } label: {
            // Board C5: rows 88 tall; the handle, the picture, then the name on about 240.
            HStack(spacing: sizing(Spacing.m)) {
                MarkerIcon(.handle, size: sizing(32), color: CrayonColor.softText)
                KitIcon(KitSlot(iconName: mission.picture), size: sizing(48))
                VStack(alignment: .leading, spacing: 0) {
                    Text(mission.name).crayonType(.body).foregroundStyle(CrayonColor.ink)
                    if let days = store.state.daysCaption(mission) {
                        Text(days).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    }
                }
                Spacer()
                MarkerIcon(.chevronRight, size: sizing(28), color: CrayonColor.softText)
            }
            .frame(height: sizing(88))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .draggable(mission.id.uuidString)
        .dropDestination(for: String.self) { ids, _ in
            guard let id = ids.first.flatMap(UUID.init(uuidString:)) else { return false }
            store.send(.moved(id, to: index))
            return true
        }
    }

    /// Board C5's side column: empty since (plain screens); "Ready by" comes with N2.
    private var side: some View { EmptyView() }
}
