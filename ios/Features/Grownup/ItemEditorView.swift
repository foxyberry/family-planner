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
            // Spec "Scrolling on G1 / G2": the form card stays put and its rows scroll inside it; the
            // side column scrolls on its own.
            GrownupScreen(scrolls: false) {
                header
            } content: { layout in
                HStack(alignment: .top, spacing: layout.gap) {
                    // Exactly the card's inner width, so no row can widen the card past 64 … 882.
                    PaperCard(seed: 31, trailingInset: layout.editorTrailingInset) {
                        ScrollColumn(scrollTarget: store.scrollTarget) {
                            Group { if store.isEditingMissions { missionsPage } else { form } }
                                .frame(width: layout.editorRowsWidth, alignment: .leading)
                        }
                    }
                    .frame(width: layout.form.width, height: layout.form.height)
                    ScrollColumn {
                        Group {
                            if store.isEditingWeekly { weeklySide } else if let preview = store.preview {
                                sideColumn(preview)
                            }
                        }
                    }
                    .frame(width: layout.side.width, height: layout.action.minY - layout.side.minY - Spacing.s,
                           alignment: .topLeading)
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
                switch card.kind {
                case .from: fromCard
                case .bring: bringCard
                case .runsEnd: runsEndCard
                case .noSchool: noSchoolCard
                }
            }
            if let draft = store.missionDraft {
                CrayonColor.dim.ignoresSafeArea()
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
                CrayonColor.dim.ignoresSafeArea()
                    .onTapGesture { store.send(.fromWhenCancelTapped) }
                fromWhenCard
            }
            if let title = store.confirmTitle {
                CrayonColor.dim.ignoresSafeArea()
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

    /// A form row's card (boards F1–F4): Done keeps the changes, Cancel or a tap outside puts them back.
    private func formCard(_ title: String, width: CGFloat, height: CGFloat = 420,
                          @ViewBuilder content: () -> some View) -> some View {
        FormCard(title: title, size: CGSize(width: width, height: height), done: L10n.tr("c5.done"),
                 cancel: L10n.tr("card.cancel"), onDone: { store.send(.cardDoneTapped) },
                 onCancel: { store.send(.cardClosed) }, content: content)
    }

    /// Board F3 Ends: End of this term (with its date), on a date, after a number of times, or no end.
    private var runsEndCard: some View {
        formCard(L10n.tr("runs.card.title"), width: 560) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(store.runsEndRows, id: \.kind) { row in
                    PickRow(row.title, caption: row.caption, isPicked: row.isPicked) {
                        store.send(.runsEndKindPicked(row.kind))
                    }
                    if row.isPicked { runsEndDetail(row.kind).padding(.leading, 56) }
                }
            }
        }
    }

    /// The picked end's own control: the date, or − {n} times +.
    @ViewBuilder private func runsEndDetail(_ kind: ItemForm.RunsEndKind) -> some View {
        switch kind {
        case .date:
            DateField(label: store.runsEndText,
                      date: Binding(get: { store.runsUntil }, set: { store.send(.runsUntilPicked($0)) }))
                .padding(.vertical, Spacing.xs)
        case .count:
            HStack(spacing: Spacing.m) {
                RoundButton(glyph: .minus, accessibilityLabel: L10n.tr("runs.pick.count")) { store.send(.runsTimesStepped(-1)) }
                    .size(64)
                Text(L10n.tr("runs.count.value", store.form.times)).crayonType(.body, bold: true)
                    .foregroundStyle(CrayonColor.ink).frame(width: 140)
                RoundButton(glyph: .plus, accessibilityLabel: L10n.tr("runs.pick.count")) { store.send(.runsTimesStepped(1)) }
                    .size(64)
            }
            .padding(.vertical, Spacing.xs)
        case .term, .none:
            EmptyView()
        }
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

    /// Board F1 From: Home or an event to follow; after an event, "Starts − {n} min after +".
    private var fromCard: some View {
        formCard(L10n.tr("editor.row.from"), width: 640) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                ChoiceCircles(store.fromCircles) { store.send(.fromPicked($0)) }
                if store.form.after != nil {
                    HStack(spacing: Spacing.m) {
                        Text(L10n.tr("from.starts")).crayonType(.body, bold: true).foregroundStyle(CrayonColor.softText)
                            .frame(width: 140, alignment: .leading)
                        RoundButton(glyph: .minus, accessibilityLabel: store.gapText) { store.send(.fromGapStepped(-1)) }
                            .size(64)
                        Text(store.gapText).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink)
                            .frame(width: 200)
                        RoundButton(glyph: .plus, accessibilityLabel: store.gapText) { store.send(.fromGapStepped(1)) }
                            .size(64)
                    }
                }
            }
        }
    }

    /// Board F4 No school days (an item after School): Skip, or at a set time from Home with its own
    /// end and Going.
    private var noSchoolCard: some View {
        formCard(L10n.tr("no_school.card.title"), width: 640, height: 560) {
            VStack(alignment: .leading, spacing: 0) {
                PickRow(L10n.tr("no_school.pick.skip"), isPicked: store.form.noSchoolStart == nil) {
                    store.send(.noSchoolSetTime(false))
                }
                PickRow(L10n.tr("no_school.pick.at"), isPicked: store.form.noSchoolStart != nil) {
                    store.send(.noSchoolSetTime(true))
                }
                if store.form.noSchoolStart != nil {
                    VStack(alignment: .leading, spacing: Spacing.s) {
                        HStack(spacing: Spacing.m) {
                            TimeField(label: store.noSchoolTimeLabel,
                                      time: Binding(get: { store.noSchoolTime }, set: { store.send(.noSchoolStartPicked($0)) }),
                                      width: 210)
                            MarkerIcon(.arrowRight, size: 32, color: CrayonColor.ink)
                            TimeField(label: store.noSchoolEndLabel,
                                      time: Binding(get: { store.noSchoolEndTime }, set: { store.send(.noSchoolEndPicked($0)) }),
                                      width: 210)
                        }
                        ChoiceCircles(store.noSchoolGoing) { id in store.send(.noSchoolGoingTapped(Domain.Way(rawValue: id))) }
                    }
                    .padding(.leading, 56)
                    .padding(.top, Spacing.xs)
                }
            }
        }
    }

    /// Board F2 Bring: up to four things in one row and "More", which opens every object picture.
    private var bringCard: some View {
        formCard(L10n.tr("editor.row.bring"), width: 640) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                ChoiceCircles(store.bringRow) { store.send(.bringCircleTapped($0)) }
                if store.isPickingMoreBring {
                    ScrollView {
                        IconPicker(picked: store.bringPicked, slots: store.bringSlots, columns: 5) { store.send(.bringToggled($0)) }
                    }
                    .frame(maxHeight: 320)
                }
            }
        }
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
            // Board F5: "Before" and "After" are heads over C5 rows (88) and "+ Add".
            Text(title).crayonType(.head).foregroundStyle(CrayonColor.ink)
                .padding(.top, Spacing.s)
            ForEach(Array(missions.enumerated()), id: \.element.id) { index, mission in
                missionRow(mission, index: index, section: section)
            }
            if store.state.canAddMission(section) {
                HStack(spacing: Spacing.m) {
                    RoundButton(glyph: .plus, accessibilityLabel: L10n.tr("missions.add")) {
                        store.send(.missionAddTapped(section))
                    }
                    .size(56)
                    Button { store.send(.missionAddTapped(section)) } label: {
                        Text(L10n.tr("missions.add")).crayonType(.body).foregroundStyle(CrayonColor.link)
                            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHidden(true)
                }
                .frame(height: 88)
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
    /// Board G5, the shared DesignSystem card.
    private var fromWhenCard: some View {
        FromWhenCard(title: L10n.tr("from_when.title"), tabs: store.fromWhenTabs,
                     selection: Binding(get: { store.fromWhen ?? .today }, set: { store.send(.fromWhenPicked($0)) }),
                     dateChoice: ItemEditorFeature.FromWhen.date, dateLabel: store.fromWhenDateLabel,
                     date: Binding(get: { store.fromWhenDateValue }, set: { store.send(.fromWhenDatePicked($0)) }),
                     caption: store.fromWhenCaption, save: L10n.tr("from_when.save"), cancel: L10n.tr("from_when.cancel"),
                     onSave: { store.send(.fromWhenSaveTapped) }, onCancel: { store.send(.fromWhenCancelTapped) })
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
