import ComposableArchitecture
import CrayonKit
import DesignSystem
import Domain
import KitArt
import ScheduleStore
import SwiftUI

/// Add to the day / edit an item (boards C3, C4, C3k, G2).
public struct ItemEditorView: View {
    @Environment(\.sizing) private var sizing
    @Bindable var store: StoreOf<ItemEditorFeature>
    /// Board C3k: the Name label turns `pickBlue` while its field has focus.
    @State private var isNameFocused = false

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
                    PaperCard(seed: 31) {
                        ScrollColumn(scrollTarget: store.scrollTarget) {
                            form
                                .frame(width: layout.editorRowsWidth, alignment: .leading)
                        }
                    }
                    .frame(width: layout.form.width, height: layout.form.height)
                    ScrollColumn {
                        Group {
                            if store.isEditingWeekly { weeklySide } else if let preview = store.preview {
                                // Board C3k: while the keyboard is open only the preview heading stays.
                                sideColumn(preview, headingOnly: layout.keyboardTop != nil)
                            }
                        }
                    }
                    .frame(width: layout.side.width, height: layout.action.minY - layout.side.minY - sizing(Spacing.s),
                           alignment: .topLeading)
                }
            } primaryAction: { layout in
                VStack(alignment: .leading, spacing: sizing(Spacing.xs)) {
                    InkButton(store.primaryTitle, isEnabled: store.canSave) { store.send(.saveTapped) }
                        .frame(width: layout.side.width)
                    if let error = store.saveError {
                        Text(error).crayonType(.caption).foregroundStyle(CrayonColor.lateText)
                    }
                }
            }
            if let card = store.card {
                switch card.kind {
                case .from: fromCard
                case .before: beforeCard
                case .back: backCard
                case .runsEnd: runsEndCard
                case .noSchool: noSchoolCard
                }
            }
            if store.fromWhen != nil {
                CrayonColor.dim.fullBleed()
                    .onTapGesture { store.send(.fromWhenCancelTapped) }
                fromWhenCard
            }
            if let title = store.confirmTitle {
                let card = ConfirmCard(title: title, message: store.confirmMessage,
                                       cancel: store.confirmCancelTitle, confirm: store.confirmAcceptTitle,
                                       isDestructive: store.confirmIsDestructive,
                                       onCancel: { store.send(.confirmCancelled) },
                                       onConfirm: { store.send(.confirmAccepted) })
                if store.confirmPointsAtBack {
                    // Board C3x: the dim starts under the header, so "←" stays in sight above it.
                    CrayonColor.dim.padding(.horizontal, -sizing.bleed).ignoresSafeArea(edges: .bottom)
                        .padding(.top, sizing.y(124))
                        .onTapGesture { store.send(.confirmCancelled) }
                    card.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.leading, sizing.x(40))
                        .padding(.top, sizing.y(140))
                        .ignoresSafeArea(.container, edges: .top)
                } else {
                    CrayonColor.dim.fullBleed()
                    card
                }
            }
        }
        .task { await store.send(.task).finish() }
    }

    private var header: some View {
        GrownupHeader(title: store.title, caption: store.headerCaption,
                      onBack: { store.send(.backTapped) })
    }

    // MARK: Form

    /// Layout v56: rows 24 apart between drawn edges (C3 180 / 264 / 364 / 456 / 548 / 632 / 718).
    private var form: some View {
        VStack(alignment: .leading, spacing: sizing.formRowGap) {
            row(store.forLabel) { audienceTabs }
            // Board C3: five pictures and "More", which opens every picture, 6 per row.
            row(store.whatLabel) {
                PictureRow(slots: store.whatRow.compactMap(KitSlot.init(rawValue:)),
                           selection: Binding(get: { store.form.iconName.flatMap(KitSlot.init(rawValue:)) },
                                              set: { if let slot = $0 { store.send(.picturePicked(slot.rawValue)) } }),
                           all: ItemEditorFeature.State.pictures, flags: ItemEditorFeature.State.flags,
                           isShowingAll: store.isPickingMorePictures,
                           moreTitle: store.moreTitle) {
                    store.send(.morePicturesTapped)
                }
            }
            .zIndex(1)
            // Board C3: the name field fills the control column (232 … 842).
            row(store.nameLabel, problem: .name, isActive: isNameFocused) {
                CrayonField(store.nameLabel, text: $store.form.name).frame(maxWidth: .infinity)
                    .onPreferenceChange(FieldFocusKey.self) { focused in
                        Task { @MainActor in isNameFocused = focused }
                    }
            }
            row(store.whenLabel, problem: .when) { whenRow }
            if !store.isEditingWeekly {
                row(store.repeatLabel) {
                    // Layout v45: "Once · Weekly · Monthly", 3 × 180, gap 12.
                    CrayonTabs(selection: Binding(get: { store.form.repeats }, set: { store.send(.repeatChanged($0)) }),
                               items: store.repeatTabs.map { ($0.0, $0.1, nil) },
                               widths: Array(repeating: 180, count: 3), spacing: Spacing.sm)
                }
            }
            // Board G3: This day keeps the item's own rows only (no Days, Runs or event rows).
            if store.isThisDay {
                EmptyView()
            } else {
                switch store.form.repeats {
                case .weekly: weeklyRows
                // Board G2m: editing an every-month series uses the series rows, no date strip.
                case .monthly: if store.isEditingWeekly { weeklyRows } else { monthlyRows }
                case .once: onceRows
                }
            }
            if case .editOnce = store.mode {
                Button { store.send(.removeTapped) } label: {
                    Text(store.removeTitle).crayonType(.head).foregroundStyle(CrayonColor.lateText)
                        .frame(height: sizing(88))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func row(_ label: String, problem row: FormRow? = nil, isActive: Bool = false,
                     @ViewBuilder control: () -> some View) -> some View {
        let shown = row.flatMap { store.state.problem(for: $0) }
        // Labels on 78, controls on 192 (GrownupLayout, layout v56). A problem (spec
        // "Add-screen feedback") turns the field's outline `lateText` and its caption sits right under
        // the field, taking its own line.
        return HStack(alignment: .controlMiddle, spacing: 0) {
            FormLabel(label, isActive: isActive).alignmentGuide(.controlMiddle) { $0[VerticalAlignment.center] }
            VStack(alignment: .leading, spacing: sizing(Spacing.xxs)) {
                control().fieldProblem(shown != nil)
                    .alignmentGuide(.controlMiddle) { $0[VerticalAlignment.center] }
                if let shown {
                    Text(shown.message).crayonType(.caption).foregroundStyle(CrayonColor.lateText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .drawnRow()
        .id(row?.rawValue)
    }


    private var audienceTabs: some View {
        // Board C3: three tabs 180 × 72, gap 12. They wrap if
        // the column is too narrow.
        CrayonTabs(selection: Binding(get: { store.form.audience }, set: { store.send(.audienceTapped($0)) }),
                   items: store.audienceTabs.map { ($0.audience, $0.title, $0.badge) },
                   itemSize: CGSize(width: 180, height: 72), spacing: Spacing.sm)
    }

    private var whenRow: some View {
        VStack(alignment: .leading, spacing: sizing(Spacing.xs)) {
            HStack(spacing: sizing(Spacing.s)) {
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
        row(store.daysLabel, problem: .days) {
            if store.form.repeats == .monthly {
                // Board G2m: the Days row holds the rule tabs, made from the series' start.
                monthlyRuleTabs
            } else {
                HStack(spacing: sizing(Spacing.sm)) {
                    ForEach(Weekday.allCases.sorted(), id: \.self) { day in
                        DayChip(DayText.initial(day), isOn: Binding(get: { store.form.days.contains(day) },
                                                                    set: { _ in store.send(.dayToggled(day)) }))
                    }
                }
            }
        }
        // Board G2: Runs, "{start}" → "End of term", then Skip school holidays.
        row(store.runsLabel) {
            HStack(spacing: sizing(Spacing.s)) {
                DateField(label: store.runsStartText,
                          date: Binding(get: { store.runsStart }, set: { store.send(.runsStartPicked($0)) }))
                MarkerIcon(.arrowRight, size: sizing(32), color: CrayonColor.softText)
                FieldButton(store.runsEndText) { store.send(.runsEndTapped) }
            }
        }
        if store.showsSkipHolidays {
            row("") {
                checkbox(store.skipHolidaysTitle, isOn: store.form.skipsHolidays) { store.form.skipsHolidays.toggle() }
            }
        }
        eventRows
    }

    /// A form row's card (boards F1–F4): Done keeps the changes, Cancel or a tap outside puts them back.
    private func formCard(_ title: String, width: CGFloat, height: CGFloat = 420,
                          @ViewBuilder content: () -> some View) -> some View {
        FormCard(title: title, size: CGSize(width: width, height: height), done: store.cardDoneTitle,
                 cancel: store.cardCancelTitle, onDone: { store.send(.cardDoneTapped) },
                 onCancel: { store.send(.cardClosed) }, content: content)
    }

    /// Board F3 Ends: End of this term (with its date), on a date, after a number of times, or no end.
    private var runsEndCard: some View {
        formCard(store.runsCardTitle, width: 560) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(store.runsEndRows, id: \.kind) { row in
                    PickRow(row.title, caption: row.caption, isPicked: row.isPicked) {
                        store.send(.runsEndKindPicked(row.kind))
                    }
                    if row.isPicked { runsEndDetail(row.kind).padding(.leading, sizing(56)) }
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
                .padding(.vertical, sizing(Spacing.xs))
        case .count:
            HStack(spacing: sizing(Spacing.m)) {
                RoundButton(glyph: .minus) { store.send(.runsTimesStepped(-1)) }
                    .size(64).enabled(store.form.timesEnds.canLower)
                Text(store.runsCountText).crayonType(.body, bold: true)
                    .foregroundStyle(CrayonColor.ink).frame(width: sizing(140))
                RoundButton(glyph: .plus) { store.send(.runsTimesStepped(1)) }
                    .size(64).enabled(store.form.timesEnds.canRaise)
            }
            .padding(.vertical, sizing(Spacing.xs))
        case .term, .none:
            EmptyView()
        }
    }

    @ViewBuilder private var onceRows: some View {
        dateStrip
        row("") {
            // Board C4 (v20): the check, then the star it adds to the clock (40), then the words.
            checkbox(store.starTitle, isOn: store.form.showsStar, picture: .star) { store.form.showsStar.toggle() }
        }
        eventRows
    }

    /// Board C3m: the date strip picks the first date, then "{nth} {weekday}" · "Day {d}" (they
    /// fill the controls column), then Skip school holidays.
    @ViewBuilder private var monthlyRows: some View {
        dateStrip
        row("") { monthlyRuleTabs }
        if store.showsSkipHolidays {
            row("") {
                checkbox(store.skipHolidaysTitle, isOn: store.form.skipsHolidays) { store.form.skipsHolidays.toggle() }
            }
        }
        eventRows
    }

    /// "2nd Sat" · "Day 14", filling the controls column (layout v42: 2 × 299 on the board).
    private var monthlyRuleTabs: some View {
        CrayonTabs(selection: Binding(get: { store.form.monthlyByDate },
                                      set: { store.send(.monthlyRuleTapped(byDate: $0)) }),
                   items: store.monthlyChoices.map { ($0.byDate, $0.title, nil) },
                   fills: true, spacing: Spacing.sm)
    }

    /// Board C4: ‹ (64) in the label column, five date chips (96) 12 apart, then ›. ‹ is off on the
    /// first page of dates.
    private var dateStrip: some View {
        HStack(spacing: 0) {
            FormLabelColumn {
                RoundButton(glyph: .chevronLeft) { store.send(.datePageTapped(-1)) }
                    .size(64)
                    .enabled(store.canPageEarlier)
            }
            HStack(spacing: sizing(Spacing.sm)) {
                ForEach(store.dateChips, id: \.day) { chip in
                    DateChip(weekday: chip.weekday, day: chip.day.day, isOn: chip.isOn) {
                        store.send(.dateTapped(chip.day))
                    }
                }
                RoundButton(glyph: .chevronRight) { store.send(.datePageTapped(1)) }
                    .size(64)
            }
        }
    }

    /// Spec "Event form rows for 6b" (board G2b): From, then Going / Leave when From is Home (C3g),
    /// then Bring and Medal; one line each on a 96 pitch, "›" at 790.
    @ViewBuilder private var eventRows: some View {
        linkRow(store.fromLabel, action: .fromRowTapped) {
            Text(store.fromText).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(1)
        }
        if store.showsNoSchool {
            linkRow(store.noSchoolLabel, action: .noSchoolRowTapped) {
                Text(store.noSchoolText).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(1)
            }
        }
        if store.showsGoing { goingRows }
        // Issue 024 (board G2b, layout v77): Before (bundles and Bring) on outings, Back (the way home)
        // on the last event of a chain, 70 apart, then Medal.
        if store.showsBefore {
            linkRow(store.beforeLabel, action: .beforeRowTapped) {
                if let text = store.beforeText {
                    HStack(spacing: sizing(Spacing.sm)) {
                        if let picture = store.beforePicture { KitIcon(picture, size: sizing(48)) }
                        Text(text).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(1)
                    }
                } else {
                    nothing
                }
            }
        }
        if store.showsBack {
            linkRow(store.backLabel, action: .backRowTapped) {
                if let text = store.backText {
                    HStack(spacing: sizing(Spacing.sm)) {
                        if let picture = store.backPicture { KitIcon(picture, size: sizing(48)) }
                        Text(text).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(1)
                    }
                } else {
                    Text(store.backNoneText).crayonType(.body).foregroundStyle(CrayonColor.softText)
                }
            }
        }
        row(store.medalLabel) {
            // Off without a trip: the switch draws the off look and the button takes no taps
            // (`.disabled` would dim a plain button a second time).
            Button { store.send(.medalToggled) } label: {
                CrayonSwitch(isOn: store.form.medalIsOn, isEnabled: store.form.canSwitchMedal)
            }
                .buttonStyle(.plain)
                .allowsHitTesting(store.form.canSwitchMedal)
                .frame(height: sizing(72))
        }
    }

    private var nothing: some View {
        Text(store.nothingText).crayonType(.body).foregroundStyle(CrayonColor.softText)
    }

    /// A one-line row that opens a card or a page: the value, then "›" at the row's end (814 … 842).
    private func linkRow(_ label: String, action: ItemEditorFeature.Action,
                         @ViewBuilder value: () -> some View) -> some View {
        row(label) {
            Button { store.send(action) } label: {
                HStack(spacing: sizing(Spacing.sm)) {
                    value()
                    Spacer(minLength: 0)
                    MarkerIcon(.chevronRight, size: sizing(28), color: CrayonColor.softText)
                }
                // Spec "Alignment contract": a borderless value row ends drawn on 802.
                .padding(.trailing, sizing.inset)
                .frame(maxWidth: .infinity, minHeight: sizing(72))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: From and Bring cards (centred, a tap outside cancels)

    /// Board F1 From: Home or an event to follow; after an event, "Starts − {n} min after +".
    private var fromCard: some View {
        formCard(store.fromLabel, width: 640) {
            VStack(alignment: .leading, spacing: sizing(Spacing.s)) {
                ChoiceCircles(store.fromCircles) { store.send(.fromPicked($0)) }
                if store.form.after != nil {
                    HStack(spacing: sizing(Spacing.m)) {
                        Text(store.startsLabel).crayonType(.body, bold: true).foregroundStyle(CrayonColor.softText)
                            .frame(width: sizing(140), alignment: .leading)
                        RoundButton(glyph: .minus) { store.send(.fromGapStepped(-1)) }
                            .size(64).enabled(store.form.gapEnds.canLower)
                        Text(store.gapText).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink)
                            .frame(width: sizing(200))
                        RoundButton(glyph: .plus) { store.send(.fromGapStepped(1)) }
                            .size(64).enabled(store.form.gapEnds.canRaise)
                    }
                }
            }
        }
    }

    /// Board F4 No school days (an item after School): Skip, or at a set time from Home with its own
    /// end and Going.
    private var noSchoolCard: some View {
        formCard(store.noSchoolCardTitle, width: 640, height: 560) {
            VStack(alignment: .leading, spacing: 0) {
                PickRow(store.noSchoolSkipTitle, isPicked: store.form.noSchoolStart == nil) {
                    store.send(.noSchoolSetTime(false))
                }
                PickRow(store.noSchoolAtTitle, isPicked: store.form.noSchoolStart != nil) {
                    store.send(.noSchoolSetTime(true))
                }
                if store.form.noSchoolStart != nil {
                    VStack(alignment: .leading, spacing: sizing(Spacing.s)) {
                        HStack(spacing: sizing(Spacing.m)) {
                            TimeField(label: store.noSchoolTimeLabel,
                                      time: Binding(get: { store.noSchoolTime }, set: { store.send(.noSchoolStartPicked($0)) }),
                                      width: sizing(210))
                            MarkerIcon(.arrowRight, size: sizing(32), color: CrayonColor.ink)
                            TimeField(label: store.noSchoolEndLabel,
                                      time: Binding(get: { store.noSchoolEndTime }, set: { store.send(.noSchoolEndPicked($0)) }),
                                      width: sizing(210))
                        }
                        ChoiceCircles(store.noSchoolGoing) { id in store.send(.noSchoolGoingTapped(Domain.Way(rawValue: id))) }
                    }
                    .padding(.leading, sizing(56))
                    .padding(.top, sizing(Spacing.xs))
                }
            }
        }
    }

    /// Board F2 / F2k Before: the kid's bundles and Bring (four things and "More").
    private var beforeCard: some View {
        BeforeCard(title: store.beforeLabel, kidTabs: store.beforeKidTabs,
                   kid: store.beforeKidShown.map { kid in Binding(get: { kid }, set: { store.send(.beforeKidPicked($0)) }) },
                   bundlesCaption: store.bundlesCaption, chips: store.bundleChips, bringCaption: store.bringCaption,
                   done: store.cardDoneTitle, cancel: store.cardCancelTitle, onToggle: { store.send(.bundleToggled($0)) },
                   onDone: { store.send(.cardDoneTapped) }, onCancel: { store.send(.cardClosed) }) {
            VStack(alignment: .leading, spacing: sizing(Spacing.s)) {
                ChoiceCircles(store.bringRow) { store.send(.bringCircleTapped($0)) }
                if store.isPickingMoreBring {
                    ScrollView {
                        IconPicker(picked: store.bringPicked, slots: store.bringSlots, columns: 5) { store.send(.bringToggled($0)) }
                    }
                    .frame(maxHeight: sizing(320))
                }
            }
        }
    }

    /// Board F7 Back: the way home and how long it takes.
    private var backCard: some View {
        BackCard(title: store.backLabel, choices: store.backChoices, takes: store.backTakes, done: store.cardDoneTitle,
                 cancel: store.cardCancelTitle, onPick: { store.send(.wayHomePicked($0)) },
                 onStep: { store.send(.homeAfterStepped($0)) }, onDone: { store.send(.cardDoneTapped) },
                 onCancel: { store.send(.cardClosed) })
    }

    /// Board C3g: how the kid goes, and when they leave (Walk, Car, Taxi) or "Uses Our buses ›".
    @ViewBuilder private var goingRows: some View {
        row(store.goingLabel) {
            ChoiceCircles(store.goingChoices) { id in store.send(.goingTapped(Domain.Way(rawValue: id))) }
        }
        if let trip = store.form.trip {
            row(store.leaveLabel) {
                if trip.way == .bus {
                    Button { store.send(.busesRowTapped) } label: {
                        GlyphText(store.usesBusesTitle, glyph: .chevronRight, type: .body, color: CrayonColor.link)
                    }
                    .buttonStyle(.plain)
                } else if let leave = store.form.leaveText, let caption = store.form.leaveCaption {
                    HStack(spacing: sizing(Spacing.m)) {
                        RoundButton(glyph: .minus) { store.send(.leaveStepped(-1)) }
                            .enabled(store.form.leaveEnds.canLower)
                        Text(leave).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink)
                            .frame(width: sizing(112))
                        RoundButton(glyph: .plus) { store.send(.leaveStepped(1)) }
                            .enabled(store.form.leaveEnds.canRaise)
                        Text(caption).crayonType(.body).foregroundStyle(CrayonColor.softText)
                    }
                }
            }
        }
    }

    private func checkbox(_ title: String, isOn: Bool, picture: KitSlot? = nil,
                          toggle: @escaping () -> Void) -> some View {
        Button(action: toggle) {
            HStack(spacing: sizing(Spacing.sm)) {
                CheckMark(isDone: isOn, size: 48)
                if let picture { KitIcon(picture, size: sizing(40)) }
                Text(title).crayonType(.body).foregroundStyle(CrayonColor.ink)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: Side column (every-week item, board G2)

    private var weeklySide: some View {
        VStack(alignment: .leading, spacing: sizing(Spacing.s)) {
            if store.showsScopeTabs {
                // Boards G2 / G3: This day / All days at the top of the side column.
                // Layout v42 fill rule: the two tabs share the side column (2 × 230, gap 12).
                CrayonTabs(selection: Binding(get: { store.editScope }, set: { store.send(.scopeTapped($0)) }),
                           items: store.scopeTabs.map { ($0.0, $0.1, nil) },
                           fills: true, spacing: Spacing.sm)
            }
            if store.isThisDay {
                if let title = store.thisDayTitle {
                    Text(title).crayonType(.head).foregroundStyle(CrayonColor.ink)
                }
                Button { store.send(.skipRowTapped) } label: {
                    Text(store.skipTitle).crayonType(.body).foregroundStyle(CrayonColor.ink)
                        .frame(maxWidth: .infinity, minHeight: sizing(88))
                        .partBackground(.roundedRect(cornerRadius: 26), fill: CrayonStyle.paper, seed: 1901)
                }
                .buttonStyle(.plain)
            } else {
                Text(store.everyTitle).crayonType(.head).foregroundStyle(CrayonColor.ink)
                RemoveButton(store.removeSeriesTitle) { store.send(.removeSeriesTapped) }
            }
        }
    }

    /// Board G5 "Change from when?": a small card over the form (560 wide).
    /// Board G5, the shared DesignSystem card.
    private var fromWhenCard: some View {
        FromWhenCard(title: store.fromWhenTitle, tabs: store.fromWhenTabs,
                     selection: Binding(get: { store.fromWhenChoice }, set: { store.send(.fromWhenPicked($0)) }),
                     dateChoice: ItemEditorFeature.FromWhen.date, dateLabel: store.fromWhenDateLabel,
                     date: Binding(get: { store.fromWhenDateValue }, set: { store.send(.fromWhenDatePicked($0)) }),
                     caption: store.fromWhenCaption, save: store.fromWhenSave, cancel: store.fromWhenCancel,
                     onSave: { store.send(.fromWhenSaveTapped) }, onCancel: { store.send(.fromWhenCancelTapped) })
    }

    // MARK: Side column (preview)

    private func sideColumn(_ preview: FormPreview, headingOnly: Bool) -> some View {
        VStack(alignment: .leading, spacing: sizing(Spacing.xs)) {
            Text(preview.heading).crayonType(.head).foregroundStyle(CrayonColor.ink)
            if !headingOnly { previewBody(preview) }
        }
    }

    @ViewBuilder private func previewBody(_ preview: FormPreview) -> some View {
        Group {
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
        HStack(spacing: sizing(Spacing.sm)) {
            KitIcon(KitSlot(iconName: row.slot.iconName), size: sizing(48))
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
