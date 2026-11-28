import ComposableArchitecture
import CrayonKit
import DesignSystem
import Domain
import KitArt
import SwiftUI

/// G4 · Edit School (board G4; first part): School, When, Days, Arrive by + latest, Going
/// and Medal, one row each on the editor rows (labels 80, controls 208, to 818). The side column
/// reads "Every school day"; Save changes sits at its foot.
public struct SchoolEditorView: View {
    @Environment(\.sizing) private var sizing
    @Bindable var store: StoreOf<SchoolEditorFeature>

    public init(store: StoreOf<SchoolEditorFeature>) {
        self.store = store
    }

    public var body: some View {
        GrownupScreen(scrolls: false) {
            GrownupHeader(title: store.title, caption: store.headerCaption,
                          onBack: { store.send(.backTapped) })
        } content: { layout in
            HStack(alignment: .top, spacing: layout.gap) {
                PaperCard(seed: 33) {
                    ScrollColumn {
                        rows.frame(width: layout.editorRowsWidth, alignment: .leading)
                    }
                }
                .frame(width: layout.form.width, height: layout.form.height)
                ScrollColumn {
                    VStack(alignment: .leading, spacing: sizing(Spacing.s)) {
                        // Boards G2 / G4: This day / Every time fill the side column.
                        CrayonTabs(selection: Binding(get: { store.editScope }, set: { store.send(.scopeTapped($0)) }),
                                   items: store.scopeTabs.map { ($0.0, $0.1, nil) },
                                   fills: true, spacing: Spacing.sm)
                        if store.isThisDay {
                            Text(store.thisDayTitle).crayonType(.head).foregroundStyle(CrayonColor.ink)
                            if store.canSkipDay {
                                Button { store.send(.skipDayTapped) } label: {
                                    Text(store.skipTitle).crayonType(.body).foregroundStyle(CrayonColor.ink)
                                        .frame(maxWidth: .infinity, minHeight: sizing(88))
                                        .partBackground(.roundedRect(cornerRadius: 26), fill: CrayonStyle.paper, seed: 1901)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            Text(store.everyTitle).crayonType(.head).foregroundStyle(CrayonColor.ink)
                            // The waiting hours change: it can be cancelled (spec G5 "What Settings shows meanwhile").
                            if let cancel = store.cancelChangeTitle {
                                Button { store.send(.cancelChangeTapped) } label: {
                                    Text(cancel).crayonType(.body, bold: true).foregroundStyle(CrayonColor.lateText)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(width: layout.side.width, height: layout.action.minY - layout.side.minY - sizing(Spacing.s),
                       alignment: .topLeading)
            }
        } primaryAction: { layout in
            VStack(alignment: .leading, spacing: sizing(Spacing.xs)) {
                InkButton(store.saveTitle, isEnabled: store.canSave) { store.send(.saveTapped) }
                    .frame(width: layout.side.width)
                if let error = store.saveError {
                    Text(error).crayonType(.caption).foregroundStyle(CrayonColor.lateText)
                }
            }
        }
        .overlay {
            if store.isBringOpen { bringCard }
            if store.isBackOpen { backCard }
            if store.isAskingFromWhen {
                CrayonColor.dim.fullBleed()
                    .onTapGesture { store.send(.fromWhenCancelTapped) }
                fromWhenCard
            }
            // Spec #255: "Cancel this change" asks first (centred over the dim, as G7's cancel).
            if store.isConfirmingCancel {
                CrayonColor.dim.fullBleed().onTapGesture { store.send(.cancelKept) }
                ConfirmCard(title: store.cancelConfirmTitle, message: nil, cancel: store.cancelConfirmKeep,
                            confirm: store.cancelConfirmAction, isDestructive: true,
                            onCancel: { store.send(.cancelKept) }, onConfirm: { store.send(.cancelConfirmed) })
            }
        }
        .task { await store.send(.task).finish() }
    }

    /// Board G5 over G4: an Every time save asks from when (the shared DesignSystem card).
    private var fromWhenCard: some View {
        FromWhenCard(title: store.fromWhenTitle, tabs: store.fromWhenTabs,
                     selection: Binding(get: { store.fromWhenChoice }, set: { store.send(.fromWhenPicked($0)) }),
                     dateChoice: FromWhenTabs.Choice.date, dateLabel: store.fromWhenDateLabel,
                     date: Binding(get: { store.fromWhenDateValue }, set: { store.send(.fromWhenDatePicked($0)) }),
                     caption: nil, save: store.fromWhenSave, cancel: store.fromWhenCancel,
                     onSave: { store.send(.fromWhenSaveTapped) }, onCancel: { store.send(.fromWhenCancelTapped) })
    }

    /// Board F2 over G4 (issue 024): Before, the kid's bundles, then School's things to bring (up to
    /// four; "More" shows the whole kit).
    private var bringCard: some View {
        BeforeCard<Kid.ID, _>(title: store.beforeLabel, kidTabs: [], kid: nil, bundlesCaption: store.bundlesCaption,
                              chips: store.bundleChips, bringCaption: store.bringLabel, done: store.bringDoneTitle,
                              cancel: store.bringCancelTitle, onToggle: { store.send(.bundleToggled($0)) },
                              onDone: { store.send(.bringDoneTapped) }, onCancel: { store.send(.bringClosed) }) {
            VStack(alignment: .leading, spacing: sizing(Spacing.s)) {
                ScrollView {
                    IconPicker(picked: store.bringPicked, slots: store.bringSlots, columns: 5) { store.send(.bringToggled($0)) }
                }
                .frame(maxHeight: sizing(320))
                Button { store.send(.bringMoreTapped) } label: {
                    Text(store.bringMoreTitle).crayonType(.body, bold: true).foregroundStyle(CrayonColor.link)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Board F7 over G4: how the kid comes home from School, and how long it takes.
    private var backCard: some View {
        BackCard(title: store.backLabel, choices: store.backChoices, takes: store.backTakes, done: store.bringDoneTitle,
                 cancel: store.bringCancelTitle, onPick: { store.send(.wayHomePicked($0)) },
                 onStep: { store.send(.homeAfterStepped($0)) }, onDone: { store.send(.backDoneTapped) },
                 onCancel: { store.send(.backClosed) })
    }

    private func linkRow(_ label: String, action: SchoolEditorFeature.Action, @ViewBuilder value: () -> some View)
        -> some View {
        Button { store.send(action) } label: {
            ListRow(leading: label, minHeight: sizing.fieldHeight) {
                HStack {
                    value()
                    Spacer(minLength: 0)
                    MarkerIcon(.chevronRight, size: sizing(28), color: CrayonColor.softText)
                }
                // Spec "Alignment contract": a value row ends drawn on 802.
                .padding(.trailing, sizing.inset)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Layout v56: rows 24 apart between drawn edges; crayon rows (time fields, chips) lay out their
    /// drawn box, value rows draw to their frame.
    private var rows: some View {
        VStack(alignment: .leading, spacing: sizing.formRowGap) {
            // Board G4: the school's name; changing the school itself is G7 (not built yet).
            // Board G4: School › opens G7 (change school); a change waiting for its day shows under it.
            linkRow(store.schoolLabel, action: .changeSchoolTapped) {
                KitIcon(.actSchool, size: sizing(48))
                Text(store.schoolName).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(1)
            }
            if let pending = store.pendingLine {
                ListRow(leading: "", minHeight: sizing(56)) {
                    Text(pending).crayonType(.caption).foregroundStyle(CrayonColor.softText).lineLimit(1)
                }
            }
            ListRow(leading: store.whenLabel, minHeight: sizing.fieldHeight) {
                HStack(spacing: sizing(Spacing.s)) {
                    TimeField(label: store.startLabel, time: Binding(get: { store.startDate },
                                                                     set: { store.send(.startPicked($0)) }),
                              width: sizing.timeFieldWidth)
                    MarkerIcon(.arrowRight, size: sizing(40), color: CrayonColor.softText)
                    TimeField(label: store.endLabel, time: Binding(get: { store.endDate },
                                                                   set: { store.send(.endPicked($0)) }),
                              width: sizing.timeFieldWidth)
                }
            }
            .drawnRow()
            // Today's hours above; a waiting change below them opens here on its own hours.
            if let waiting = store.waitingLine {
                linkRow("", action: .waitingRowTapped) {
                    Text(waiting).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(1)
                }
            }
            ListRow(leading: store.daysLabel, minHeight: sizing.fieldHeight) {
                HStack(spacing: sizing(Spacing.sm)) {
                    ForEach(Weekday.allCases.sorted(), id: \.self) { day in
                        DayChip(DayText.initial(day), isOn: Binding(
                            get: { store.state.isDayOn(day) },
                            set: { _ in store.send(.dayToggled(day)) }))
                    }
                }
            }
            .drawnRow()
            // As on S2: Arrive, then latest (the grace sets the medals).
            ListRow(leading: store.arriveByRowLabel, minHeight: sizing.fieldHeight) {
                HStack(spacing: sizing(Spacing.s)) {
                    TimeField(label: store.arriveByLabel,
                              time: Binding(get: { store.arriveByDate }, set: { store.send(.arriveByPicked($0)) }),
                              width: sizing.timeFieldWidth)
                    Text(store.latestWord).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    TimeField(label: store.latestLabel,
                              time: Binding(get: { store.latestDate }, set: { store.send(.latestPicked($0)) }),
                              width: sizing.timeFieldWidth)
                }
            }
            .drawnRow()
            // Board G4 Terms: the term text, and the S2 MOE switch only for a school our data
            // doesn't know or one typed by hand.
            ListRow(leading: store.termsLabel, minHeight: sizing.fieldHeight) {
                VStack(alignment: .leading, spacing: sizing(Spacing.xs)) {
                    Text(store.termsText).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(2)
                    if store.showsMoeCheck {
                        Button { store.send(.moeTermsToggled) } label: {
                            HStack(spacing: sizing(Spacing.s)) {
                                CheckMark(isDone: store.usesMoeTerms, size: 40)
                                Text(store.moeCheckText).crayonType(.caption).foregroundStyle(CrayonColor.ink)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            linkRow(store.goingLabel, action: .goingTapped) {
                if let picture = store.goingPicture { KitIcon(KitSlot(iconName: picture), size: sizing(48)) }
                Text(store.goingText).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(1)
            }
            linkRow(store.beforeLabel, action: .bringRowTapped) {
                if let text = store.beforeText {
                    if let picture = store.bringFirstPicture { KitIcon(KitSlot(iconName: picture), size: sizing(48)) }
                    Text(text).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(1)
                } else {
                    Text(store.nothingText).crayonType(.body).foregroundStyle(CrayonColor.softText)
                }
            }
            // Before and Back follow Every time: off on This day (#289 review).
            .offLook(store.listRowsEnabled)
            if store.showsBack {
                linkRow(store.backLabel, action: .backRowTapped) {
                    if let text = store.backText {
                        if let picture = store.backPicture { KitIcon(picture, size: sizing(48)) }
                        Text(text).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(1)
                    } else {
                        Text(store.backNoneText).crayonType(.body).foregroundStyle(CrayonColor.softText)
                    }
                }
                .offLook(store.listRowsEnabled)
            }
            ListRow(leading: store.medalLabel, minHeight: sizing.fieldHeight) {
                Button { store.send(.medalToggled) } label: {
                    CrayonSwitch(isOn: store.medalIsOn, isEnabled: store.canSwitchMedal)
                }
                .buttonStyle(.plain)
                .allowsHitTesting(store.canSwitchMedal)
            }
        }
    }
}
