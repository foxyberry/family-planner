import ComposableArchitecture
import CrayonKit
import DesignSystem
import KitArt
import Strings
import SwiftUI

/// G7 · Change school: the school now and the new school (the S2 search); picking one opens the
/// G7 card, "Starts on" (Next term / Date) with Save / Cancel. While a change waits for its day,
/// the pending line with "Cancel the change".
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
                if store.place == .preschool {
                    InkButton(L10n.tr("change_school.save")) { store.send(.preschoolSaveTapped) }
                        .disabled(!store.canContinuePreschool)
                        .frame(width: layout.side.width)
                }
            }
            if store.isShowingStartsOn {
                // Board G7: the card over the screen; tap outside = Cancel.
                CrayonColor.dim.ignoresSafeArea().onTapGesture { store.send(.cardCancelled) }
                VStack(spacing: Spacing.xs) {
                    FromWhenCard(title: store.cardTitle, tabs: store.startsOnTabs,
                                 selection: Binding(get: { store.startsOn }, set: { store.send(.startsOnTapped($0)) }),
                                 dateChoice: ChangeSchoolFeature.StartsOn.date, dateLabel: store.startLabel,
                                 date: Binding(get: { store.dateValue }, set: { store.send(.datePicked($0)) }),
                                 caption: store.startsOnCaption, save: L10n.tr("change_school.save"),
                                 cancel: L10n.tr("from_when.cancel"), tabWidths: [184, 130],
                                 onSave: { store.send(.saveTapped) }, onCancel: { store.send(.cardCancelled) })
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
        .keyboardHidden(when: store.isShowingStartsOn)
        .task { await store.send(.task).finish() }
    }

    /// S2's top rows (design session 2026-11-15): Goes to (tabs 180 × 72, gap 12), then the place's
    /// rows where S2 has them: the school search, or the preschool's name and hours; At home has none.
    private func rows(_ layout: GrownupLayout) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ListRow(leading: L10n.tr("s2.goes"), minHeight: 72) {
                CrayonTabs(selection: Binding(get: { Optional(store.place) },
                                              set: { if let place = $0 { store.send(.placeTapped(place)) } }),
                           items: store.placeTabs.map { (Optional($0.0), $0.1, nil) },
                           itemSize: CGSize(width: 180, height: 72), spacing: Spacing.sm)
            }
            switch store.place {
            case .school: schoolSearch(layout)
            case .preschool: preschoolRows
            case .home: EmptyView()
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
        }
    }

    private func schoolSearch(_ layout: GrownupLayout) -> some View {
        ListRow(leading: L10n.tr("s2.school"), minHeight: 80) {
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
    }

    /// S2's preschool rows: the typed name, then drop-off and pick-up.
    @ViewBuilder private var preschoolRows: some View {
        ListRow(leading: L10n.tr("s2.preschool"), minHeight: 80) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                CrayonField(L10n.tr("s2.preschool.placeholder"),
                            text: Binding(get: { store.preschoolName }, set: { store.send(.preschoolNameChanged($0)) }))
                    .frame(width: 400)
                Text(L10n.tr("s2.preschool.hint")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
            }
        }
        ListRow(leading: L10n.tr("s2.hours"), minHeight: 80) {
            HStack(spacing: Spacing.s) {
                time(store.dropOff, placeholder: 450) { store.send(.dropOffPicked($0)) }
                MarkerIcon(.arrowRight, size: 40, color: CrayonColor.softText)
                time(store.pickUp, placeholder: 900) { store.send(.pickUpPicked($0)) }
            }
        }
    }

    private func time(_ minute: Int?, placeholder: Int, set: @escaping (Date) -> Void) -> some View {
        let label = store.state.timeLabel(minute, placeholder: placeholder)
        return TimeField(label: label.text,
                         time: Binding(get: { store.state.timeDate(minute, placeholder: placeholder) }, set: set),
                         isPlaceholder: label.isPlaceholder, width: 180)
    }
}
