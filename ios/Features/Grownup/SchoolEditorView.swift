import ComposableArchitecture
import CrayonKit
import DesignSystem
import Domain
import KitArt
import Strings
import SwiftUI

/// G4 · Edit School (board G4, layout v47; first part): School, When, Days, Arrive by + latest, Going
/// and Medal, one row each on the editor rows (labels 80, controls 208, to 818). The side column
/// reads "Every school day"; Save changes sits at its foot.
public struct SchoolEditorView: View {
    @Bindable var store: StoreOf<SchoolEditorFeature>

    public init(store: StoreOf<SchoolEditorFeature>) {
        self.store = store
    }

    public var body: some View {
        GrownupScreen(scrolls: false) {
            GrownupHeader(title: store.title, onBack: { store.send(.backTapped) })
        } content: { layout in
            HStack(alignment: .top, spacing: layout.gap) {
                PaperCard(seed: 33, trailingInset: layout.editorTrailingInset) {
                    ScrollColumn {
                        rows.frame(width: layout.editorRowsWidth, alignment: .leading)
                    }
                }
                .frame(width: layout.form.width, height: layout.form.height)
                ScrollColumn {
                    Text(store.everyTitle).crayonType(.head).foregroundStyle(CrayonColor.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: layout.side.width, height: layout.action.minY - layout.side.minY - Spacing.s,
                       alignment: .topLeading)
            }
        } primaryAction: { layout in
            VStack(alignment: .leading, spacing: Spacing.xs) {
                InkButton(L10n.tr("editor.primary.save")) { store.send(.saveTapped) }
                    .frame(width: layout.side.width)
                    .disabled(!store.canSave)
                if let error = store.saveError {
                    Text(error).crayonType(.caption).foregroundStyle(CrayonColor.lateText)
                }
            }
        }
        .task { await store.send(.task).finish() }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            // Board G4: the school's name; changing the school itself is G7 (not built yet).
            ListRow(leading: L10n.tr("settings.school"), minHeight: 80) {
                HStack(spacing: Spacing.sm) {
                    KitIcon(.actSchool, size: 48)
                    Text(store.schoolName).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(1)
                }
            }
            ListRow(leading: L10n.tr("editor.row.when"), minHeight: 80) {
                HStack(spacing: Spacing.s) {
                    TimeField(label: store.startLabel, time: Binding(get: { store.startDate },
                                                                     set: { store.send(.startPicked($0)) }))
                        .frame(width: 176)
                    MarkerIcon(.arrowRight, size: 40, color: CrayonColor.softText)
                    TimeField(label: store.endLabel, time: Binding(get: { store.endDate },
                                                                   set: { store.send(.endPicked($0)) }))
                        .frame(width: 176)
                }
            }
            ListRow(leading: L10n.tr("editor.row.days"), minHeight: 80) {
                HStack(spacing: Spacing.sm) {
                    ForEach(Weekday.allCases.sorted(), id: \.self) { day in
                        DayChip(DayText.initial(day), isOn: Binding(
                            get: { store.school?.days.contains(day) ?? false },
                            set: { _ in store.send(.dayToggled(day)) }))
                    }
                }
            }
            // As on S2: Arrive by, then latest (the grace sets the medals).
            ListRow(leading: L10n.tr("s2.arrive_by"), minHeight: 80) {
                HStack(spacing: Spacing.s) {
                    TimeField(label: store.arriveByLabel,
                              time: Binding(get: { store.arriveByDate }, set: { store.send(.arriveByPicked($0)) }))
                        .frame(width: 176)
                    Text(L10n.tr("s2.latest")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    TimeField(label: store.latestLabel,
                              time: Binding(get: { store.latestDate }, set: { store.send(.latestPicked($0)) }))
                        .frame(width: 176)
                }
            }
            Button { store.send(.goingTapped) } label: {
                ListRow(leading: L10n.tr("going.label"), minHeight: 80) {
                    HStack {
                        KitIcon(.busDouble, size: 48)
                        Text(store.goingText).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(1)
                        Spacer(minLength: 0)
                        MarkerIcon(.chevronRight, size: 28, color: CrayonColor.softText)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            ListRow(leading: L10n.tr("editor.row.medal"), minHeight: 80) {
                Button { store.send(.medalToggled) } label: { CrayonSwitch(isOn: store.medal) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.tr("editor.row.medal"))
                    .accessibilityAddTraits(store.medal ? .isSelected : [])
            }
        }
    }
}
