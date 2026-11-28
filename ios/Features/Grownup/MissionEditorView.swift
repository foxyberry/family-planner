import ComposableArchitecture
import CrayonKit
import DesignSystem
import Domain
import KitArt
import Strings
import SwiftUI

/// C5 · Routines (board C5, issue 024): the kid's bundles in the side column; the card edits the
/// picked one: its name, then its missions in circle order (drag ≡ to reorder, tap a row to change it).
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
                    bundleFoot.frame(width: layout.side.width)
                    InkButton(store.doneTitle) { store.send(.doneTapped) }
                        .frame(width: layout.side.width)
                    if let error = store.saveError {
                        Text(error).crayonType(.caption).foregroundStyle(CrayonColor.lateText)
                    }
                }
            }
            if let confirm = store.state.removeBundleConfirm {
                CrayonColor.dim.fullBleed()
                    .onTapGesture { store.send(.removeBundleCancelled) }
                ConfirmCard(title: confirm.title, message: confirm.message, cancel: store.keepLabel,
                            confirm: store.removeLabel, isDestructive: true,
                            onCancel: { store.send(.removeBundleCancelled) }, onConfirm: { store.send(.removeBundleConfirmed) })
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
            // Board C5: the Name row first (label 78, field 192–802), then the missions.
            if store.bundle != nil {
                HStack(spacing: 0) {
                    FormLabel(store.nameLabel)
                    CrayonField(store.nameLabel, text: Binding(get: { store.bundleName },
                                                               set: { store.send(.bundleNameChanged($0)) }))
                        .frame(maxWidth: .infinity)
                }
                .padding(.bottom, sizing(Spacing.m))
            }
            // Layout v21: no divider lines inside cards; the rows are separated by space only.
            ForEach(Array(store.rows.enumerated()), id: \.element.id) { index, mission in
                row(mission, index: index)
            }
            if store.canAdd {
                AddRow(store.addTitle) { store.send(.addTapped) }
            } else if store.bundle != nil {
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

    /// Board C5's side column: the kid's bundles (472 × 88, 16 apart) and "New bundle"; at its foot
    /// "Used by {events}" and "Remove {bundle}".
    private var side: some View {
        VStack(alignment: .leading, spacing: sizing(Spacing.s)) {
            ForEach(store.state.bundleRows, id: \.id) { row in
                BundleButton(row.name, isPicked: row.isPicked) { store.send(.bundleTapped(row.id)) }
            }
            AddRow(store.newBundleTitle, seed: 1802) { store.send(.newBundleTapped) }
        }
    }

    /// Board C5: above "Done", "Used by {events}" and "Remove {bundle}".
    @ViewBuilder private var bundleFoot: some View {
        if let used = store.usedByCaption {
            Text(used).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        if let remove = store.removeBundleTitle {
            RemoveButton(remove) { store.send(.removeBundleTapped) }
                .padding(.bottom, sizing(Spacing.m))
        }
    }
}
