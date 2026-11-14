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
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        // Boards G2 / G4: This day / All days fill the side column (layout v42).
                        CrayonTabs(selection: Binding(get: { store.editScope }, set: { store.send(.scopeTapped($0)) }),
                                   items: [(SchoolEditorFeature.Scope.thisDay, L10n.tr("editor.scope.this_day"), nil),
                                           (.allDays, L10n.tr("editor.scope.all_days"), nil)],
                                   fills: true, spacing: Spacing.sm)
                        Text(store.everyTitle).crayonType(.head).foregroundStyle(CrayonColor.ink)
                    }
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
        .overlay {
            if store.isBringOpen { bringCard }
        }
        .task { await store.send(.task).finish() }
    }

    /// Board F2 over G4: School's things to bring, up to four; "More" shows the whole kit.
    private var bringCard: some View {
        FormCard(title: L10n.tr("editor.row.bring"), size: CGSize(width: 640, height: 420), done: L10n.tr("c5.done"),
                 cancel: L10n.tr("card.cancel"), onDone: { store.send(.bringDoneTapped) },
                 onCancel: { store.send(.bringClosed) }) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                ScrollView {
                    IconPicker(picked: store.bringPicked, slots: store.bringSlots, columns: 5) { store.send(.bringToggled($0)) }
                }
                .frame(maxHeight: 320)
                Button { store.send(.bringMoreTapped) } label: {
                    Text(L10n.tr("picker.more")).crayonType(.body, bold: true).foregroundStyle(CrayonColor.link)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func linkRow(_ label: String, action: SchoolEditorFeature.Action, @ViewBuilder value: () -> some View)
        -> some View {
        Button { store.send(action) } label: {
            ListRow(leading: label, minHeight: 80) {
                HStack {
                    value()
                    Spacer(minLength: 0)
                    MarkerIcon(.chevronRight, size: 28, color: CrayonColor.softText)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            // Board G4: the school's name; changing the school itself is G7 (not built yet).
            // Board G4: School › opens G7 (change school); a change waiting for its day shows under it.
            linkRow(L10n.tr("settings.school"), action: .changeSchoolTapped) {
                KitIcon(.actSchool, size: 48)
                Text(store.schoolName).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(1)
            }
            if let pending = store.pendingLine {
                ListRow(leading: "", minHeight: 56) {
                    Text(pending).crayonType(.caption).foregroundStyle(CrayonColor.softText).lineLimit(1)
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
            // Board G4 Terms: the term text, and the S2 MOE switch for a school that can follow it.
            ListRow(leading: L10n.tr("settings.terms"), minHeight: 80) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(store.termsText).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(2)
                    if store.showsMoeCheck {
                        Button { store.send(.moeTermsToggled) } label: {
                            HStack(spacing: Spacing.s) {
                                CheckMark(isDone: store.usesMoeTerms, size: 40)
                                Text(L10n.tr("s2.terms.moe")).crayonType(.caption).foregroundStyle(CrayonColor.ink)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            linkRow(L10n.tr("going.label"), action: .goingTapped) {
                KitIcon(.busDouble, size: 48)
                Text(store.goingText).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(1)
            }
            linkRow(L10n.tr("editor.row.bring"), action: .bringRowTapped) {
                if let picture = store.bringFirstPicture, let text = store.bringText {
                    KitIcon(KitSlot(iconName: picture), size: 48)
                    Text(text).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(1)
                } else {
                    Text(L10n.tr("editor.row.nothing")).crayonType(.body).foregroundStyle(CrayonColor.softText)
                }
            }
            ListRow(leading: L10n.tr("editor.row.medal"), minHeight: 80) {
                Button { store.send(.medalToggled) } label: { CrayonSwitch(isOn: store.medal) }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.tr("editor.row.medal"))
                    .accessibilityAddTraits(store.medal ? .isSelected : [])
            }
        }
    }
}
