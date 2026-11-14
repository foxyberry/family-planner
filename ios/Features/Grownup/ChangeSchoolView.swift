import ComposableArchitecture
import CrayonKit
import DesignSystem
import KitArt
import Strings
import SwiftUI

/// G7 · Change school: the school now, the new school (the S2 search), "Starts on" (Next term /
/// Date), and while a change waits for its day, the pending line with "Cancel the change".
public struct ChangeSchoolView: View {
    @Bindable var store: StoreOf<ChangeSchoolFeature>

    public init(store: StoreOf<ChangeSchoolFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            GrownupScreen(scrolls: false) {
                GrownupHeader(title: store.title, onBack: { store.send(.backTapped) })
            } content: { layout in
                PaperCard(seed: 39, trailingInset: layout.editorTrailingInset) {
                    ScrollColumn { rows(layout).frame(width: layout.editorRowsWidth, alignment: .leading) }
                }
                .frame(width: layout.form.width, height: layout.form.height, alignment: .top)
            } primaryAction: { layout in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    InkButton(L10n.tr("change_school.save")) { store.send(.saveTapped) }
                        .frame(width: layout.side.width)
                        .disabled(!store.canSave)
                    if let error = store.saveError {
                        Text(error).crayonType(.caption).foregroundStyle(CrayonColor.lateText)
                    }
                }
            }
            if store.isConfirmingCancel {
                CrayonColor.dim.ignoresSafeArea().onTapGesture { store.send(.cancelKept) }
                ConfirmCard(title: store.cancelTitle, message: nil, cancel: L10n.tr("change_school.cancel.keep"),
                            confirm: L10n.tr("change_school.cancel.stay"), isDestructive: true,
                            onCancel: { store.send(.cancelKept) }, onConfirm: { store.send(.cancelConfirmed) })
            }
        }
        .task { await store.send(.task).finish() }
    }

    private func rows(_ layout: GrownupLayout) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ListRow(leading: L10n.tr("settings.school"), minHeight: 80) {
                HStack(spacing: Spacing.sm) {
                    KitIcon(.actSchool, size: 48)
                    Text(store.currentName).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(1)
                }
            }
            if let pending = store.pendingLine {
                ListRow(leading: "", minHeight: 72) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(pending).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(2)
                        Button { store.send(.cancelChangeTapped) } label: {
                            Text(L10n.tr("change_school.cancel")).crayonType(.body, bold: true)
                                .foregroundStyle(CrayonColor.lateText)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            ListRow(leading: L10n.tr("change_school.new"), minHeight: 80) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    CrayonField(L10n.tr("s2.school.placeholder"),
                                text: Binding(get: { store.text }, set: { store.send(.textChanged($0)) }))
                        .frame(width: 400)
                    if !store.matches.isEmpty {
                        ResultListCard(rows: store.matches.map { entry in
                            .init(id: entry.id, title: entry.name, caption: entry.caption) { store.send(.picked(entry)) }
                        }, visibleRows: 5, seed: 77, width: layout.controlWidth)
                    }
                }
            }
            ListRow(leading: L10n.tr("change_school.starts_on"), minHeight: 80) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    CrayonTabs(selection: Binding(get: { store.startsOn }, set: { store.send(.startsOnTapped($0)) }),
                               items: [(ChangeSchoolFeature.StartsOn.nextTerm, L10n.tr("change_school.next_term"), nil),
                                       (.date, L10n.tr("change_school.date"), nil)],
                               widths: [184, 130], spacing: Spacing.sm)
                    if store.startsOn == .date {
                        DateField(label: store.startLabel,
                                  date: Binding(get: { store.dateValue }, set: { store.send(.datePicked($0)) }))
                    } else {
                        Text(store.startLabel).crayonType(.body).foregroundStyle(CrayonColor.softText)
                    }
                }
            }
        }
    }
}
