import ComposableArchitecture
import CrayonKit
import DesignSystem
import Domain
import KitArt
import ScheduleStore
import Strings
import SwiftUI

/// Add to the day / edit an item (boards C3, C4, C3k, E5).
public struct ItemEditorView: View {
    @Bindable var store: StoreOf<ItemEditorFeature>

    public init(store: StoreOf<ItemEditorFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            GrownupScreen(scrollTarget: store.scrollTarget) {
                header
            } content: { layout in
                HStack(alignment: .top, spacing: layout.gap) {
                    // Exactly the card's inner width, so no row can widen the card past 64 … 882.
                    PaperCard(seed: 31) {
                        Group { if store.isEditingMissions { missionsPage } else { form } }
                            .frame(width: layout.form.width - 2 * layout.formInset, alignment: .leading)
                    }
                    .frame(width: layout.form.width)
                    Group {
                        if store.isEditingWeekly { weeklySide } else if let preview = store.preview {
                            sideColumn(preview)
                        }
                    }
                    .frame(width: layout.side.width, alignment: .topLeading)
                }
            } primaryAction: { layout in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    InkButton(store.primaryTitle) { store.send(.saveTapped) }
                        .frame(width: layout.side.width)
                        .disabled(!store.canSave)
                    if let error = store.saveError {
                        Text(error).crayonType(.caption).foregroundStyle(CrayonColor.lateText)
                    }
                }
            }
            if let card = store.card {
                CrayonColor.marker.opacity(0.3).ignoresSafeArea()
                    .onTapGesture { store.send(.cardClosed) }
                switch card {
                case .from: fromCard
                case .bring: bringCard
                case .runsEnd: runsEndCard
                case .noSchool: noSchoolCard
                }
            }
            if let draft = store.missionDraft {
                CrayonColor.marker.opacity(0.3).ignoresSafeArea()
                    .onTapGesture { store.send(.missionDraftClosed) }
                if let title = store.missionRemoveTitle {
                    ConfirmCard(title: title, message: nil, cancel: L10n.tr("c5.remove.keep"),
                                confirm: L10n.tr("c5.remove"), isDestructive: true,
                                onCancel: { store.send(.missionRemoveCancelled) },
                                onConfirm: { store.send(.missionRemoveConfirmed) })
                } else {
                    MissionDraftCard(draft: draft, onName: { store.send(.missionNameChanged($0)) },
                                     onPicture: { store.send(.missionPicturePicked($0)) },
                                     onRemove: { store.send(.missionRemoveTapped) },
                                     onSave: { store.send(.missionSaveTapped) })
                }
            }
            if store.fromWhen != nil {
                CrayonColor.marker.opacity(0.3).ignoresSafeArea()
                    .onTapGesture { store.send(.fromWhenCancelTapped) }
                fromWhenCard
            }
            if let title = store.confirmTitle {
                CrayonColor.marker.opacity(0.3).ignoresSafeArea()
                ConfirmCard(title: title, message: store.confirmMessage,
                            cancel: store.confirmCancelTitle, confirm: store.confirmAcceptTitle,
                            isDestructive: store.confirmIsDestructive,
                            onCancel: { store.send(.confirmCancelled) }, onConfirm: { store.send(.confirmAccepted) })
            }
        }
        .task { await store.send(.task).finish() }
    }

    private var header: some View {
        GrownupHeader(title: store.title, onBack: { store.send(.backTapped) })
    }

    // MARK: Form

    private var form: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            row(L10n.tr("editor.row.for")) { audienceTabs }
            // Board C3 (layout v6): five pictures and "More", which opens every picture, 6 per row.
            row(L10n.tr("editor.row.what")) {
                PictureRow(slots: store.whatRow.compactMap(KitSlot.init(rawValue:)),
                           selection: Binding(get: { store.form.iconName.flatMap(KitSlot.init(rawValue:)) },
                                              set: { if let slot = $0 { store.send(.picturePicked(slot.rawValue)) } }),
                           all: ItemEditorFeature.State.pictures, isShowingAll: store.isPickingMorePictures,
                           moreTitle: L10n.tr("picker.more"), moreLabel: L10n.tr("picker.more.label")) {
                    store.send(.morePicturesTapped)
                }
            }
            .zIndex(1)
            // Board C3: the name field fills the control column (232 … 842).
            row(L10n.tr("editor.row.name"), problem: .name) {
                CrayonField(L10n.tr("editor.row.name"), text: $store.form.name).frame(maxWidth: .infinity)
            }
            row(L10n.tr("editor.row.when"), problem: .when) { whenRow }
            if !store.isEditingWeekly {
                row(L10n.tr("editor.row.repeat")) {
                    CrayonTabs(selection: Binding(get: { store.form.repeats }, set: { store.send(.repeatChanged($0)) }),
                               items: [(ItemForm.Repeat.once, L10n.tr("editor.repeat.once"), nil),
                                       (.weekly, L10n.tr("editor.repeat.weekly"), nil)],
                               itemSize: CGSize(width: 220, height: 72), spacing: Spacing.sm)
                }
            }
            // Board G3: This day keeps the item's own rows only (no Days, Runs or event rows).
            if store.isThisDay {
                EmptyView()
            } else if store.form.repeats == .weekly { weeklyRows } else { onceRows }
            if case .editOnce = store.mode {
                Button { store.send(.removeTapped) } label: {
                    Text(store.removeTitle).crayonType(.head).foregroundStyle(CrayonColor.lateText)
                        .frame(height: 88)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func row(_ label: String, problem row: FormRow? = nil, @ViewBuilder control: () -> some View)
        -> some View {
        let shown = row.flatMap { store.state.problem(for: $0) }
        // Labels from 104, controls on 232 (GrownupLayout, boards C3 / C4 / E5). A problem (spec
        // "Add-screen feedback") turns the field's outline `lateText` and its caption sits right under
        // the field, taking its own line.
        return HStack(alignment: .controlMiddle, spacing: 0) {
            FormLabel(label).alignmentGuide(.controlMiddle) { $0[VerticalAlignment.center] }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                control().fieldProblem(shown != nil)
                    .alignmentGuide(.controlMiddle) { $0[VerticalAlignment.center] }
                if let shown {
                    Text(shown.message).crayonType(.caption).foregroundStyle(CrayonColor.lateText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .id(row?.rawValue)
    }

    private var audienceTabs: some View {
        // Board C3: three tabs 180 × 72, gap 12.
        CrayonTabs(selection: Binding(get: { store.form.audience }, set: { store.send(.audienceTapped($0)) }),
                   items: store.audienceTabs.map { ($0.audience, $0.title, $0.badge) },
                   itemSize: CGSize(width: 180, height: 72), spacing: Spacing.sm)
    }

    private var whenRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.s) {
                if let linked = store.linkedStartText {
                    // Spec "Event form rows", From: a linked item starts when its event ends.
                    Text(linked).crayonType(.body).foregroundStyle(CrayonColor.softText)
                } else {
                    TimeField(label: store.startLabel,
                              time: Binding(get: { store.startTime }, set: { store.send(.startPicked($0)) }))
                }
                Image(systemName: "arrow.right").crayonType(.body).fontWeight(.bold)
                    .foregroundStyle(CrayonColor.softText)
                TimeField(label: store.endLabel, time: Binding(get: { store.endTime }, set: { store.send(.endPicked($0)) }))
                if let duration = store.form.durationCaption {
                    Text(duration).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                }
            }
            if let overlap = store.overlapCaption {
                Text(overlap).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder private var weeklyRows: some View {
        row(L10n.tr("editor.row.days"), problem: .days) {
            HStack(spacing: Spacing.sm) {
                ForEach(Weekday.allCases.sorted(), id: \.self) { day in
                    DayChip(DayText.initial(day), isOn: Binding(get: { store.form.days.contains(day) },
                                                                set: { _ in store.send(.dayToggled(day)) }))
                }
            }
        }
        // Board G2: Runs, "{start}" → "End of term", then Skip school holidays.
        row(L10n.tr("editor.row.runs")) {
            HStack(spacing: Spacing.s) {
                DateField(label: store.runsStartText,
                          date: Binding(get: { store.runsStart }, set: { store.send(.runsStartPicked($0)) }))
                MarkerIcon(.arrowRight, size: 32, color: CrayonColor.softText)
                FieldButton(store.runsEndText) { store.send(.runsEndTapped) }
            }
        }
        if store.showsSkipHolidays {
            row("") {
                checkbox(L10n.tr("editor.skip_holidays"), isOn: store.form.skipsHolidays) { store.form.skipsHolidays.toggle() }
            }
        }
        eventRows
    }

    /// Board G2 Runs' end: End of term (with its date), a date, a number of times, or no end.
    private var runsEndCard: some View {
        PaperCard(seed: 49) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text(L10n.tr("runs.card.title")).crayonType(.head).foregroundStyle(CrayonColor.ink)
                CrayonTabs(selection: Binding(get: { store.form.runsEnd }, set: { store.send(.runsEndKindPicked($0)) }),
                           items: store.runsEndTabs.map { ($0.0, $0.1, nil) },
                           itemSize: CGSize(width: 150, height: 72), spacing: Spacing.sm)
                Group {
                    switch store.form.runsEnd {
                    case .term:
                        Text(store.termCaption ?? "").crayonType(.body).foregroundStyle(CrayonColor.softText)
                    case .date:
                        DateField(label: store.runsEndText,
                                  date: Binding(get: { store.runsUntil }, set: { store.send(.runsUntilPicked($0)) }))
                    case .count:
                        HStack(spacing: Spacing.m) {
                            RoundButton(glyph: .minus, accessibilityLabel: L10n.tr("runs.tab.count")) {
                                store.send(.runsTimesStepped(-1))
                            }
                            Text(L10n.tr("runs.count.value", store.form.times)).crayonType(.body, bold: true)
                                .foregroundStyle(CrayonColor.ink).frame(width: 140)
                            RoundButton(glyph: .plus, accessibilityLabel: L10n.tr("runs.tab.count")) {
                                store.send(.runsTimesStepped(1))
                            }
                        }
                    case .none:
                        EmptyView()
                    }
                }
                .frame(minHeight: 80, alignment: .leading)
                HStack {
                    Spacer()
                    InkButton(L10n.tr("c5.done")) { store.send(.runsEndDoneTapped) }
                        .frame(width: 240)
                }
            }
            // Interim until the card boards (iPad review): 720 wide and at least 420 tall.
            .frame(maxWidth: .infinity, minHeight: 420 - 2 * Spacing.l, alignment: .topLeading)
        }
        .frame(width: 720)
    }

    @ViewBuilder private var onceRows: some View {
        // Board C4 (layout v6): ‹ (64) in the label column at 104, five date chips (96) 12 apart
        // from 232 to 760, › (64) at 772; both centred on the chip row.
        HStack(spacing: 0) {
            FormLabelColumn {
                RoundButton(glyph: .chevronLeft, accessibilityLabel: L10n.tr("editor.dates.earlier")) { store.send(.datePageTapped(-1)) }
                    .size(64)
                    .opacity(store.canPageEarlier ? 1 : 0.3)
            }
            HStack(spacing: Spacing.sm) {
                ForEach(store.dateChips, id: \.day) { chip in
                    DateChip(weekday: chip.weekday, day: chip.day.day, isOn: chip.isOn) {
                        store.send(.dateTapped(chip.day))
                    }
                }
                RoundButton(glyph: .chevronRight, accessibilityLabel: L10n.tr("editor.dates.later")) { store.send(.datePageTapped(1)) }
                    .size(64)
            }
        }
        row("") {
            // Board C4 (v20): the check, then the star it adds to the clock (40), then the words.
            checkbox(L10n.tr("editor.star"), isOn: store.form.showsStar, picture: .star) { store.form.showsStar.toggle() }
        }
        eventRows
    }

    /// Spec "Event form rows for 6b" (board G2b): From, then Going / Leave when From is Home (C3g),
    /// then Bring, Missions and Medal; one line each on a 96 pitch, "›" at 814.
    @ViewBuilder private var eventRows: some View {
        linkRow(L10n.tr("editor.row.from"), action: .fromRowTapped) {
            Text(store.fromText).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(1)
        }
        if store.showsNoSchool {
            linkRow(L10n.tr("editor.row.no_school"), action: .noSchoolRowTapped) {
                Text(store.noSchoolText).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(1)
            }
        }
        if store.showsGoing { goingRows }
        linkRow(L10n.tr("editor.row.bring"), action: .bringRowTapped) {
            if let first = store.form.bring.first, let text = store.form.bringText {
                HStack(spacing: Spacing.sm) {
                    KitIcon(KitSlot(iconName: first.picture), size: 48)
                    Text(text).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(1)
                }
            } else {
                nothing
            }
        }
        linkRow(L10n.tr("editor.row.missions"), action: .missionsRowTapped) {
            if let text = store.form.missionsText {
                Text(text).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(1)
            } else {
                nothing
            }
        }
        row(L10n.tr("editor.row.medal")) {
            Button { store.send(.medalToggled) } label: { CrayonSwitch(isOn: store.form.medalIsOn) }
                .buttonStyle(.plain)
                .opacity(store.form.canSwitchMedal ? 1 : 0.45)
                .disabled(!store.form.canSwitchMedal)
                .accessibilityLabel(L10n.tr("editor.row.medal"))
                .accessibilityAddTraits(store.form.medalIsOn ? .isSelected : [])
                .frame(height: 72)
        }
    }

    private var nothing: some View {
        Text(L10n.tr("editor.row.nothing")).crayonType(.body).foregroundStyle(CrayonColor.softText)
    }

    /// A one-line row that opens a card or a page: the value, then "›" at the row's end (814 … 842).
    private func linkRow(_ label: String, action: ItemEditorFeature.Action,
                         @ViewBuilder value: () -> some View) -> some View {
        row(label) {
            Button { store.send(action) } label: {
                HStack(spacing: Spacing.sm) {
                    value()
                    Spacer(minLength: 0)
                    MarkerIcon(.chevronRight, size: 28, color: CrayonColor.softText)
                }
                .frame(maxWidth: .infinity, minHeight: 72)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: From and Bring cards (centred, a tap outside cancels)

    private var fromCard: some View {
        PaperCard(seed: 45) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text(L10n.tr("editor.row.from")).crayonType(.head).foregroundStyle(CrayonColor.ink)
                ChoiceCircles(store.fromCircles) { store.send(.fromPicked($0)) }
                if store.form.after != nil {
                    // "School end + 15 min" (spec "Repeats, dates and changes", Linked time).
                    HStack(spacing: Spacing.m) {
                        RoundButton(glyph: .minus, accessibilityLabel: store.gapText) { store.send(.fromGapStepped(-1)) }
                        Text(store.gapText).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink)
                            .frame(width: 180)
                        RoundButton(glyph: .plus, accessibilityLabel: store.gapText) { store.send(.fromGapStepped(1)) }
                        Spacer()
                        InkButton(L10n.tr("c5.done")) { store.send(.cardClosed) }
                            .frame(width: 200)
                    }
                }
            }
            // Interim until the card boards (iPad review): 720 wide and at least 420 tall.
            .frame(maxWidth: .infinity, minHeight: 420 - 2 * Spacing.l, alignment: .topLeading)
        }
        .frame(width: 720)
    }

    /// No school days (an item after School): Skip, or at a set time from Home with its own Going.
    private var noSchoolCard: some View {
        PaperCard(seed: 53) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text(L10n.tr("no_school.card.title")).crayonType(.head).foregroundStyle(CrayonColor.ink)
                CrayonTabs(selection: Binding(get: { store.form.noSchoolStart != nil }, set: { store.send(.noSchoolSetTime($0)) }),
                           items: [(false, L10n.tr("no_school.tab.skip"), nil), (true, L10n.tr("no_school.tab.at"), nil)],
                           itemSize: CGSize(width: 220, height: 72), spacing: Spacing.sm)
                if store.form.noSchoolStart != nil {
                    TimeField(label: store.noSchoolTimeLabel,
                              time: Binding(get: { store.noSchoolTime }, set: { store.send(.noSchoolStartPicked($0)) }))
                    ChoiceCircles(store.noSchoolGoing) { id in store.send(.noSchoolGoingTapped(Domain.Way(rawValue: id))) }
                }
                HStack {
                    Spacer()
                    InkButton(L10n.tr("c5.done")) { store.send(.noSchoolDoneTapped) }
                        .frame(width: 240)
                }
            }
            // Interim until the card boards (iPad review): 720 wide and at least 420 tall.
            .frame(maxWidth: .infinity, minHeight: 420 - 2 * Spacing.l, alignment: .topLeading)
        }
        .frame(width: 720)
    }

    private var bringCard: some View {
        PaperCard(seed: 47) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text(L10n.tr("editor.row.bring")).crayonType(.head).foregroundStyle(CrayonColor.ink)
                ScrollView {
                    IconPicker(picked: store.bringPicked, slots: store.bringSlots) { store.send(.bringToggled($0)) }
                }
                .frame(maxHeight: store.isPickingMoreBring ? 440 : 104)
                HStack(spacing: Spacing.m) {
                    Button { store.send(.bringMoreTapped) } label: {
                        Text(L10n.tr("picker.more")).crayonType(.body).foregroundStyle(CrayonColor.link)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.tr("picker.more.label"))
                    Spacer()
                    InkButton(L10n.tr("c5.done")) { store.send(.bringDoneTapped) }
                        .frame(width: 240)
                }
            }
            // Interim until the card boards (iPad review): 720 wide and at least 420 tall.
            .frame(maxWidth: .infinity, minHeight: 420 - 2 * Spacing.l, alignment: .topLeading)
        }
        .frame(width: 720)
    }

    // MARK: Missions sub-page (in the form card)

    private var missionsPage: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            HStack(spacing: Spacing.m) {
                RoundButton(glyph: .chevronLeft, accessibilityLabel: L10n.tr("grownup.back")) {
                    store.send(.missionsBackTapped)
                }
                .size(64)
                Text(store.missionsTitle).crayonType(.head).foregroundStyle(CrayonColor.ink).lineLimit(1)
            }
            missionsSection(.before, title: L10n.tr("missions.section.before"))
            missionsSection(.after, title: L10n.tr("missions.section.after"))
        }
    }

    private func missionsSection(_ section: ItemForm.MissionSection, title: String) -> some View {
        let missions = store.form.missions(section)
        return VStack(alignment: .leading, spacing: 0) {
            Text(title).crayonType(.caption, bold: true).foregroundStyle(CrayonColor.softText)
                .padding(.top, Spacing.s)
            ForEach(Array(missions.enumerated()), id: \.element.id) { index, mission in
                missionRow(mission, index: index, section: section)
            }
            if store.state.canAddMission(section) {
                Button { store.send(.missionAddTapped(section)) } label: {
                    HStack(spacing: Spacing.s) {
                        MarkerIcon(.plus, size: 28, color: CrayonColor.link)
                            .frame(width: 56, height: 56)
                            .crayonBackground(.circle, fill: nil, seed: 1801)
                        Text(L10n.tr("missions.add")).crayonType(.body).foregroundStyle(CrayonColor.link)
                    }
                    .frame(height: 72)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Board C5's row: ≡, the picture, the name, "›"; drag ≡ to reorder within the section.
    private func missionRow(_ mission: ItemMission, index: Int, section: ItemForm.MissionSection) -> some View {
        Button { store.send(.missionRowTapped(mission.id)) } label: {
            HStack(spacing: Spacing.m) {
                MarkerIcon(.handle, size: 32, color: CrayonColor.softText)
                KitIcon(KitSlot(iconName: mission.picture), size: 48)
                Text(mission.name).crayonType(.body).foregroundStyle(CrayonColor.ink)
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
            store.send(.missionMoved(id, to: index, in: section))
            return true
        }
        .accessibilityAction(named: L10n.tr("c5.move_up")) { store.send(.missionMoved(mission.id, to: index - 1, in: section)) }
        .accessibilityAction(named: L10n.tr("c5.move_down")) { store.send(.missionMoved(mission.id, to: index + 1, in: section)) }
    }

    /// Board C3g: how the kid goes, and when they leave (Walk, Car, Taxi) or "Uses Our buses ›".
    @ViewBuilder private var goingRows: some View {
        row(L10n.tr("going.label")) {
            ChoiceCircles(store.goingChoices) { id in store.send(.goingTapped(Domain.Way(rawValue: id))) }
        }
        if let trip = store.form.trip {
            row(L10n.tr("going.leave")) {
                if trip.way == .bus {
                    Button { store.send(.busesRowTapped) } label: {
                        GlyphText(L10n.tr("going.uses_buses"), glyph: .chevronRight, type: .body, color: CrayonColor.link)
                    }
                    .buttonStyle(.plain)
                } else {
                    HStack(spacing: Spacing.m) {
                        RoundButton(glyph: .minus, accessibilityLabel: L10n.tr("going.leave")) { store.send(.leaveStepped(-1)) }
                        Text(store.form.leaveText ?? "").crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink)
                            .frame(width: 112)
                        RoundButton(glyph: .plus, accessibilityLabel: L10n.tr("going.leave")) { store.send(.leaveStepped(1)) }
                        Text(store.form.leaveCaption ?? "").crayonType(.body).foregroundStyle(CrayonColor.softText)
                    }
                }
            }
        }
    }

    private func checkbox(_ title: String, isOn: Bool, picture: KitSlot? = nil,
                          toggle: @escaping () -> Void) -> some View {
        Button(action: toggle) {
            HStack(spacing: Spacing.sm) {
                CheckMark(isDone: isOn, size: 48)
                if let picture { KitIcon(picture, size: 40) }
                Text(title).crayonType(.body).foregroundStyle(CrayonColor.ink)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: Side column (every-week item, board E5)

    private var weeklySide: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            if store.showsScopeTabs {
                // Boards G2 / G3: This day / All days at the top of the side column.
                CrayonTabs(selection: Binding(get: { store.editScope }, set: { store.send(.scopeTapped($0)) }),
                           items: [(ItemEditorFeature.Scope.thisDay, L10n.tr("editor.scope.this_day"), nil),
                                   (.allDays, L10n.tr("editor.scope.all_days"), nil)],
                           itemSize: CGSize(width: 180, height: 72), spacing: Spacing.sm)
            }
            if store.isThisDay {
                Text(store.thisDayTitle ?? "").crayonType(.head).foregroundStyle(CrayonColor.ink)
                Button { store.send(.skipRowTapped) } label: {
                    Text(store.skipTitle).crayonType(.body).foregroundStyle(CrayonColor.ink)
                        .frame(maxWidth: .infinity, minHeight: 88)
                        .partBackground(.roundedRect(cornerRadius: 26), fill: CrayonStyle.paper, seed: 1901)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Text(store.everyTitle).crayonType(.head).foregroundStyle(CrayonColor.ink)
                Button { store.send(.removeSeriesTapped) } label: {
                    Text(L10n.tr("editor.remove_series")).crayonType(.head).foregroundStyle(CrayonColor.lateText)
                        .frame(maxWidth: .infinity, minHeight: 88)
                        .partBackground(.roundedRect(cornerRadius: 26), fill: CrayonStyle.paper, seed: 1903)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Board G5 "Change from when?": a small card over the form (560 wide).
    private var fromWhenCard: some View {
        PaperCard(seed: 51) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text(L10n.tr("from_when.title")).crayonType(.head).foregroundStyle(CrayonColor.ink)
                HStack(spacing: Spacing.sm) {
                    CrayonTabs(selection: Binding(get: { store.fromWhen ?? .today }, set: { store.send(.fromWhenPicked($0)) }),
                               items: store.fromWhenTabs.map { ($0.0, $0.1, nil) },
                               itemSize: CGSize(width: 150, height: 64), spacing: Spacing.sm)
                }
                if store.fromWhen == .date {
                    DateField(label: store.fromWhenDateLabel,
                              date: Binding(get: { store.fromWhenDateValue }, set: { store.send(.fromWhenDatePicked($0)) }))
                }
                if let caption = store.fromWhenCaption {
                    Text(caption).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: Spacing.l) {
                    InkButton(L10n.tr("from_when.save")) { store.send(.fromWhenSaveTapped) }
                        .frame(width: 220)
                    Button { store.send(.fromWhenCancelTapped) } label: {
                        Text(L10n.tr("from_when.cancel")).crayonType(.head).foregroundStyle(CrayonColor.softText)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 560)
    }

    // MARK: Side column (preview)

    private func sideColumn(_ preview: FormPreview) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(preview.heading).crayonType(.head).foregroundStyle(CrayonColor.ink)
            // Boards C3/C4: rows 72 tall on an 80 pitch; C4's "Just this day" note comes after them.
            ForEach(Array(preview.rows.enumerated()), id: \.offset) { _, row in
                PreviewRow(time: row.time, isNew: row.isNew) { previewLabel(row) }
            }
            if let note = preview.note {
                Text(note)
                    .crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let summary = preview.summary {
                Text(summary).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let leave = preview.leave {
                Text(leave).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func previewLabel(_ row: FormPreview.Row) -> some View {
        HStack(spacing: Spacing.sm) {
            KitIcon(KitSlot(iconName: row.slot.iconName), size: 48)
            Text(row.title).crayonType(row.isNew ? .head : .body)
                .foregroundStyle(row.isUnnamed ? CrayonColor.softText : CrayonColor.ink).lineLimit(1)
        }
    }
}

extension VerticalAlignment {
    /// A form row's label sits on its control's middle, whatever hangs under the control.
    private enum ControlMiddle: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat { context[VerticalAlignment.center] }
    }

    static let controlMiddle = VerticalAlignment(ControlMiddle.self)
}
