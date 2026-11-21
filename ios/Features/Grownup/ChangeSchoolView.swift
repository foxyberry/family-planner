import ComposableArchitecture
import CrayonKit
import DesignSystem
import KitArt
import SwiftUI

/// G7 · Change school: the school now and the new school (the S2 search); picking one opens the
/// G7 card, "Starts on" (Next term / Date) with Save / Cancel. While a change waits for its day,
/// the pending line with "Cancel the change".
public struct ChangeSchoolView: View {
    @Bindable var store: StoreOf<ChangeSchoolFeature>
    /// The search comes to the card's top once the keyboard is up (spec "Keyboard").
    @State private var searchFocus = 0
    @State private var fieldIsFocused = false
    @Environment(\.keyboardTop) private var keyboardTop
    private static let searchID = "g7.search"

    public init(store: StoreOf<ChangeSchoolFeature>) {
        self.store = store
    }

    public var body: some View {
        // Nothing about the kid's school is drawn before the store answers (no stand-in values).
        ZStack {
            switch store.phase {
            case .loading:
                GrownupScreen(scrolls: false) {
                    GrownupHeader(title: store.title, caption: store.headerCaption, backLabel: store.backLabel,
                                  onBack: { store.send(.backTapped) })
                } content: { _ in EmptyView() } primaryAction: { _ in EmptyView() }
            case .failed:
                GrownupScreen(scrolls: false) {
                    GrownupHeader(title: store.title, caption: store.headerCaption, backLabel: store.backLabel,
                                  onBack: { store.send(.backTapped) })
                } content: { _ in
                    Text(store.loadFailedText).crayonType(.body).foregroundStyle(CrayonColor.lateText)
                } primaryAction: { _ in EmptyView() }
            case let .ready(form):
                ready(form)
            }
        }
        .keyboardHidden(when: store.hidesKeyboard)
        .task { await store.send(.task).finish() }
    }

    @ViewBuilder private func ready(_ form: ChangeSchoolFeature.Form) -> some View {
        GrownupScreen(scrolls: false) {
            GrownupHeader(title: store.title, caption: store.headerCaption, backLabel: store.backLabel,
                          onBack: { store.send(.backTapped) })
        } content: { layout in
            PaperCard(seed: 39) {
                ScrollColumn(scrollTarget: searchFocus == 0 ? nil : GrownupScrollTarget(id: Self.searchID, request: searchFocus),
                             anchor: .top) {
                    rows(form, layout).frame(width: layout.editorRowsWidth, alignment: .leading)
                }
                .onPreferenceChange(FieldFocusKey.self) { focused in
                    Task { @MainActor in fieldIsFocused = focused }
                }
                .onChange(of: keyboardTop) { _, top in
                    if top != nil, fieldIsFocused, form.place == .school { searchFocus += 1 }
                }
            }
            .frame(width: layout.form.width, height: layout.form.height, alignment: .top)
        } primaryAction: { layout in
            if form.place == .preschool {
                InkButton(form.saveTitle) { store.send(.preschoolSaveTapped) }
                    .disabled(!form.canContinuePreschool)
                    .frame(width: layout.side.width)
            }
        }
        if form.isShowingStartsOn {
            // Board G7: the card over the screen; tap outside = Cancel.
            CrayonColor.dim.ignoresSafeArea().onTapGesture { store.send(.cardCancelled) }
            VStack(spacing: Spacing.xs) {
                FromWhenCard(title: form.cardTitle, tabs: form.startsOnTabs,
                             selection: Binding(get: { form.startsOn }, set: { store.send(.startsOnTapped($0)) }),
                             dateChoice: ChangeSchoolFeature.StartsOn.date, dateLabel: form.startLabel,
                             date: Binding(get: { form.dateValue }, set: { store.send(.datePicked($0)) }),
                             caption: form.startsOnCaption, save: form.saveTitle,
                             cancel: form.cardCancelTitle, tabWidths: [184, 130],
                             onSave: { store.send(.saveTapped) }, onCancel: { store.send(.cardCancelled) })
                if let error = form.saveError {
                    Text(error).crayonType(.caption).foregroundStyle(CrayonColor.lateText)
                }
            }
        }
        if form.isConfirmingCancel {
            CrayonColor.dim.ignoresSafeArea().onTapGesture { store.send(.cancelKept) }
            ConfirmCard(title: form.cancelTitle, message: nil, cancel: form.keepTitle,
                        confirm: form.stayTitle, isDestructive: true,
                        onCancel: { store.send(.cancelKept) }, onConfirm: { store.send(.cancelConfirmed) })
        }
    }

    /// S2's top rows (design session 2026-11-15): Goes to (tabs 180 × 72, gap 12), then the place's
    /// rows where S2 has them: the school search, or the preschool's name and hours; At home has none.
    private func rows(_ form: ChangeSchoolFeature.Form, _ layout: GrownupLayout) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ListRow(leading: form.goesToLabel, minHeight: 72) {
                CrayonTabs(selection: Binding(get: { Optional(form.place) },
                                              set: { if let place = $0 { store.send(.placeTapped(place)) } }),
                           items: form.placeTabs.map { (Optional($0.0), $0.1, nil) },
                           itemSize: CGSize(width: layout.sizing.goesToTabWidth, height: 72),
                           spacing: Spacing.sm)
            }
            switch form.place {
            case .school: schoolSearch(form, layout)
            case .preschool: preschoolRows(form)
            case .home: EmptyView()
            }
            if let pending = form.pendingLine {
                ListRow(leading: "", minHeight: 72) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(pending).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(2)
                        Button { store.send(.cancelChangeTapped) } label: {
                            Text(form.cancelChangeTitle).crayonType(.body, bold: true)
                                .foregroundStyle(CrayonColor.lateText)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func schoolSearch(_ form: ChangeSchoolFeature.Form, _ layout: GrownupLayout) -> some View {
        ListRow(leading: form.schoolLabel, minHeight: 80) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                CrayonField(form.schoolPlaceholder,
                            text: Binding(get: { form.text }, set: { store.send(.textChanged($0)) }))
                    .frame(width: 400)
                if !form.matches.isEmpty {
                    ResultListCard(rows: form.matches.map { entry in
                        .init(id: entry.id, title: entry.name,
                              caption: entry.resultCaption(oneLine: layout.searchListHeight != nil)) { store.send(.picked(entry)) }
                    }, visibleRows: 5, seed: 77, width: layout.controlWidth, fitHeight: layout.searchListHeight)
                }
            }
        }
        .id(Self.searchID)
    }

    /// S2's preschool rows: the typed name, then drop-off and pick-up.
    @ViewBuilder private func preschoolRows(_ form: ChangeSchoolFeature.Form) -> some View {
        ListRow(leading: form.preschoolLabel, minHeight: 80) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                CrayonField(form.preschoolPlaceholder,
                            text: Binding(get: { form.preschoolName }, set: { store.send(.preschoolNameChanged($0)) }))
                    .frame(width: 400)
                Text(form.preschoolHint).crayonType(.caption).foregroundStyle(CrayonColor.softText)
            }
        }
        ListRow(leading: form.hoursLabel, minHeight: 80) {
            HStack(spacing: Spacing.s) {
                time(form, form.dropOff) { store.send(.dropOffPicked($0)) }
                MarkerIcon(.arrowRight, size: 40, color: CrayonColor.softText)
                time(form, form.pickUp) { store.send(.pickUpPicked($0)) }
            }
        }
    }

    private func time(_ form: ChangeSchoolFeature.Form, _ minute: Int, set: @escaping (Date) -> Void) -> some View {
        TimeField(label: form.timeLabel(minute), pickerTitle: form.timePickerTitle,
                  time: Binding(get: { form.timeDate(minute) }, set: set), width: 180)
    }
}
