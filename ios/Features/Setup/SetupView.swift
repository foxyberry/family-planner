import AppSettings
import ComposableArchitecture
import CrayonKit
import DesignSystem
import Domain
import Grownup
import KitArt
import Strings
import SwiftUI

/// First-run setup S1–S4 (boards S1, S2, S2s, S3, S4) on the grown-up frame.
public struct SetupView: View {
    @Bindable var store: StoreOf<SetupFeature>
    @Environment(\.sizing) private var sizing
    /// S2's school field asks the main column to bring it to the top once the keyboard is up
    /// (spec "Keyboard": the keyboard client decides, not focus or timing).
    @State private var searchFocus = 0
    @State private var fieldIsFocused = false
    @Environment(\.keyboardTop) private var keyboardTop

    public init(store: StoreOf<SetupFeature>) {
        self.store = store
    }

    public var body: some View {
        let layout = SetupLayout(sizing: sizing)
        // Spec "Scrolling": the main column and the side column scroll on their own; the header stays.
        GrownupScreen(scrolls: false) {
            header(layout)
        } content: { grown in
            HStack(alignment: .top, spacing: grown.gap) {
                ScrollColumn(scrollTarget: searchFocus == 0 ? nil : GrownupScrollTarget(id: SchoolStep.fieldID, request: searchFocus),
                             anchor: .top, bleed: .cardCorner(size: sizing(Sizing.cornerControl))) {
                    main(layout, listHeight: grown.searchListHeight, keyboardIsUp: grown.keyboardTop != nil)
                        .frame(width: grown.form.width, alignment: .topLeading)
                }
                .onPreferenceChange(FieldFocusKey.self) { focused in
                    Task { @MainActor in fieldIsFocused = focused }
                }
                .onChange(of: keyboardTop) { _, top in
                    if top != nil, fieldIsFocused, store.step == .school { searchFocus += 1 }
                }
                    .frame(width: grown.form.width, height: grown.form.height, alignment: .topLeading)
                    // Above the side column, so the corner ×'s touch area past the card still answers.
                    .zIndex(1)
                ScrollColumn { side(layout, keyboardIsOpen: grown.keyboardTop != nil)
                    .frame(width: grown.side.width, alignment: .topLeading) }
                    .frame(width: grown.side.width, height: grown.action.minY - grown.side.minY - sizing(Spacing.s),
                           alignment: .topLeading)
            }
        } primaryAction: { grown in
            VStack(alignment: .leading, spacing: sizing(Spacing.xs)) {
                InkButton(store.primaryTitle, arrow: true) { store.send(.nextTapped) }
                    .frame(width: grown.side.width)
                    .opacity(store.canGoNext ? 1 : 0.4)
                    .disabled(!store.canGoNext)
                if store.saveFailed {
                    Text(L10n.tr("editor.save_error")).crayonType(.caption).foregroundStyle(CrayonColor.lateText)
                }
            }
        }
        .resultVeil(isOpen: store.isResultListOpen) { store.send(.resultVeilTapped) }
        .overlay {
            if store.isConfirmingReplace {
                ZStack {
                    CrayonColor.dim.fullBleed()
                    ConfirmCard(title: L10n.tr("setup.replace.title"), message: L10n.tr("setup.replace.message"),
                                cancel: L10n.tr("setup.replace.cancel"), confirm: L10n.tr("setup.replace.accept"),
                                isDestructive: true, onCancel: { store.send(.replaceCancelled) },
                                onConfirm: { store.send(.replaceConfirmed) })
                }
            }
        }
        .fullScreenCover(item: $store.scope(state: \.dataSources, action: \.dataSources)) { sources in
            DataSourcesView(store: sources)
        }
        .fullScreenCover(item: $store.scope(state: \.changeBuses, action: \.changeBuses)) { change in
            ChangeBusesView(store: change)
        }
        .task { await store.send(.task).finish() }
    }

    // MARK: Header

    private func header(_ layout: SetupLayout) -> some View {
        HStack(spacing: layout.grown.titleGap) {
            if store.showsBack {
                RoundButton(glyph: .chevronLeft) { store.send(.backTapped) }
            }
            Text(store.title).crayonType(.title).foregroundStyle(CrayonColor.ink).lineLimit(1).layoutPriority(1)
            headerAccessory(layout)
            Spacer(minLength: sizing(Spacing.m))
            Text(store.stepText).crayonType(.caption).foregroundStyle(CrayonColor.softText).lineLimit(1).fixedSize()
            StepDots(current: store.step.number)
        }
    }

    /// S2 and S3: the kid tabs, as State lists them (spec "S3 · Getting there").
    @ViewBuilder private func headerAccessory(_ layout: SetupLayout) -> some View {
        if store.step == .school || store.step == .gettingThere {
            CrayonTabs(selection: Binding(get: { store.selectedKidTab }, set: { store.send(.kidTabTapped($0)) }),
                       items: store.kidTabs.map { tab in
                           (tab.id, tab.name, KidFace.Badge(face: tab.face, colorIndex: tab.colorIndex))
                       },
                       itemSize: SetupLayout.kidTab(faceOnly: store.kidTabsAreFaceOnly), spacing: SetupLayout.kidTabGap,
                       faceOnly: store.kidTabsAreFaceOnly,
                       marked: store.step == .gettingThere ? store.unfinishedGoingTabs : [])
        }
    }

    // MARK: Main column

    @ViewBuilder private func main(_ layout: SetupLayout, listHeight: CGFloat?, keyboardIsUp: Bool) -> some View {
        switch store.step {
        case .family: FamilyStep(store: store, layout: layout)
        case .school: SchoolStep(store: store, layout: layout, listHeight: listHeight, keyboardIsUp: keyboardIsUp)
        case .gettingThere: GoingStep(store: store)
        case .almostDone: AlmostDoneStep(store: store, layout: layout)
        }
    }

    // MARK: Side column

    /// A4 rule: while the keyboard is open the side column keeps only its words (the picture would
    /// sit under the raised button on a smaller iPad).
    @ViewBuilder private func side(_ layout: SetupLayout, keyboardIsOpen: Bool) -> some View {
        switch store.step {
        case .family:
            VStack(alignment: .leading, spacing: sizing(Spacing.m)) {
                // The kit's home picture only: the family's own home drawing is never used here.
                if !keyboardIsOpen {
                    KitIcon(.home, size: 280 * layout.grown.sizing.s).environment(\.kitArt, BundledKitArt(includePrivate: false))
                }
                Text(L10n.tr("s1.side.title")).crayonType(.head)
                Text(L10n.tr("s1.side.body")).crayonType(.body).foregroundStyle(CrayonColor.softText)
            }
            .foregroundStyle(CrayonColor.ink)
        case .school:
            if store.tabKid?.goesTo == .school {
                MedalSide(store: store)
            } else if let side = store.placeSide {
                VStack(alignment: .leading, spacing: sizing(Spacing.s)) {
                    Text(side.body).crayonType(.body).foregroundStyle(CrayonColor.ink)
                    Text(side.caption).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                }
            }
        case .gettingThere:
            // Layout v38 (plain screens): the "On school mornings" block is gone; Home comes later.
            EmptyView()
        case .almostDone:
            SummarySide(store: store, layout: layout)
        }
    }
}

// MARK: - S1 · Family

private struct FamilyStep: View {
    let store: StoreOf<SetupFeature>
    let layout: SetupLayout

    var body: some View {
        // Spec "Layout balance": each kid card hugs its rows (padding 32), cards 40 apart.
        VStack(alignment: .leading, spacing: sizing.cardGap) {
            ForEach(Array(store.kids.enumerated()), id: \.element.id) { index, kid in
                PaperCard(seed: 61 + UInt32(index), padding: sizing.cardPadding) { card(kid) }
                    .frame(width: layout.grown.form.width, alignment: .topLeading)
                    .cardCorner(size: sizing(Sizing.cornerControl)) { removeButton(kid) } popover: { removeConfirm(kid, index: index) }
                    .zIndex(store.removeConfirm == kid.id ? 1 : 0)
            }
            VStack(alignment: .leading, spacing: sizing(Spacing.xs)) {
                if store.canAddKid {
                    Button { store.send(.addKidTapped) } label: {
                        HStack(spacing: sizing(Spacing.s)) {
                            RoundButton(glyph: .plus) {}.size(72).allowsHitTesting(false)
                            Text(L10n.tr("s1.add")).crayonType(.body).foregroundStyle(CrayonColor.link)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Text(L10n.tr("s1.one_child")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
            }
            .padding(.leading, sizing.cardPadding.leading)
        }
    }

    /// Spec S1 "Remove a kid" (board v54): a round × (48, its circle is its touch area) on the card's drawn top-right corner
    /// (`cardCorner`); "Remove {name}?" hangs under it when the card has something typed.
    @ViewBuilder private func removeButton(_ kid: KidEntry) -> some View {
        if store.canRemoveKids {
            RoundButton(glyph: .close) {
                store.send(.removeKidTapped(kid.id))
            }
            .size(Sizing.cornerControl)
        }
    }

    @ViewBuilder private func removeConfirm(_ kid: KidEntry, index: Int) -> some View {
        if store.removeConfirm == kid.id {
            ConfirmCard(title: L10n.tr("s1.remove.confirm", kid.shownName(index: index)), message: nil,
                        cancel: L10n.tr("s1.remove.keep"), confirm: L10n.tr("s1.remove"), isDestructive: true,
                        onCancel: { store.send(.removeCancelled) }, onConfirm: { store.send(.removeConfirmed) })
        }
    }

    private var sizing: Sizing { layout.grown.sizing }

    /// Spec "Kid card": the shared two-row card on the form lines (user, 2026-11-21).
    private func card(_ kid: KidEntry) -> some View {
        KidCard(words: store.kidCardWords,
                name: Binding(get: { kid.name }, set: { store.send(.nameChanged(kid.id, $0)) }),
                age: Binding(get: { kid.ageText }, set: { store.send(.ageChanged(kid.id, $0)) }),
                badge: kid.badge, colorIndex: kid.colorIndex, face: kid.pickedFace,
                onColour: { store.send(.colourTapped(kid.id, $0)) }, onFace: { store.send(.faceTapped(kid.id, $0)) })
            .formLines(KidCard.lines(layout.grown, words: store.kidCardWords))
    }
}

// MARK: - S2 · School

private struct SchoolStep: View {

    @Environment(\.sizing) private var sizing
    static let fieldID = "s2.schoolField"
    let store: StoreOf<SetupFeature>
    let layout: SetupLayout
    /// Keyboard up: the list card's height down to the keyboard, with one-line rows (2026-11-15).
    let listHeight: CGFloat?
    /// With the keyboard up the list starts 8 under the field, over the caption (2026-11-15).
    let keyboardIsUp: Bool

    var body: some View {
        // Exactly the card's inner width, so no row can widen the card.
        PaperCard(seed: 71) {
            rows.frame(width: layout.grown.editorRowsWidth, alignment: .leading)
        }
        // Boards S2/S3: the card fills the main region down to 968, whatever its rows.
        .frame(width: layout.grown.form.width).frame(minHeight: layout.length(968 - 148), alignment: .topLeading)
    }

    /// Board S2: Goes to 180, School 264 (caption 346), Days 401–473, Hours 485 (caption
    /// 567), Arrive 621, terms 719; rows 24 apart between drawn edges (spec "Layout balance").
    @ViewBuilder private var rows: some View {
        if let kid = store.tabKid {
            let school = kid.school
            VStack(alignment: .leading, spacing: layout.grown.sizing.formRowGap) {
                SetupRow(label: L10n.tr("s2.goes"), height: layout.grown.sizing.tabHeight()) {
                    CrayonTabs(selection: Binding(get: { kid.goesTo }, set: { if let place = $0 { store.send(.goesToTapped(place)) } }),
                               items: SetupFeature.State.places.map { (Optional($0.0), $0.1, nil) },
                               // 180 on the board; three always fit the control column.
                               itemSize: CGSize(width: 180, height: 72),
                               spacing: Spacing.sm)
                }
                .drawnRow()
                if let line = store.atHomeLine {
                    Text(line).crayonType(.body).foregroundStyle(CrayonColor.softText)
                } else if kid.goesTo != nil {
                    form(school)
                }
            }
        }
    }

    @ViewBuilder private func form(_ school: SchoolForm) -> some View {
        row(school.kind == .preschool ? L10n.tr("s2.preschool") : L10n.tr("s2.school")) { schoolField(school) }
            .captionedRow()
            .id(Self.fieldID)
            .zIndex(1)
        // Board S2: the editor chips (72, they toggle) 8 apart; the row is as tall as the chips.
        SetupRow(label: L10n.tr("s2.days"), height: layout.grown.sizing.tabHeight()) {
            HStack(spacing: sizing(Spacing.xs)) {
                ForEach(Weekday.allCases.sorted(), id: \.self) { day in
                    DayChip(DayText.initial(day), isOn: Binding(get: { school.days.contains(day) },
                                                                set: { _ in store.send(.dayToggled(day)) }))
                }
            }
        }
        .drawnRow()
        row(L10n.tr("s2.hours")) {
            VStack(alignment: .leading, spacing: sizing.captionGap) {
                HStack(spacing: sizing(Spacing.s)) {
                    time(.start, width: sizing(180))
                    MarkerIcon(.arrowRight, size: sizing(40), color: CrayonColor.softText)
                    time(.end, width: sizing(180))
                }
                // The website caption shows only when the hours came from the site (user, 2026-11-21:
                // no blank line, so Arrive keeps the standard gap).
                if let source = school.hoursSource {
                    Text(source).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                }
            }
        }
        .captionedRow(hasCaption: school.hoursSource != nil)
        if school.kind == .school {
            // One row: Arrive by, then "latest" and the gate's time (both 180 × 80, gap 16).
            row(L10n.tr("s2.arrive_by")) {
                HStack(spacing: sizing(Spacing.s)) {
                    time(.arriveBy, width: sizing(180))
                    Text(L10n.tr("s2.latest")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    time(.latest, width: sizing(180))
                }
            }
            .drawnRow()
        }
        // Board S2 (layout v63): a school our data knows reads "Terms" + its terms as text; one it
        // doesn't know asks on the control column.
        if let value = store.termsValue {
            row(store.termsLabel) {
                VStack(alignment: .leading, spacing: sizing.captionGap) {
                    Text(value).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(1)
                    if let caption = store.termsCaption {
                        Text(caption).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    }
                }
            }
            .captionedRow(hasCaption: store.termsCaption != nil)
        } else if let terms = school.termsRow {
            termsRow(terms).padding(.leading, layout.grown.labelWidth)
        }
    }

    private func row(_ label: String, @ViewBuilder control: () -> some View) -> some View {
        SetupRow(label: label, height: layout.grown.sizing.fieldHeight, control: control)
    }

    private func time(_ row: SetupFeature.TimeRow, width: CGFloat? = nil) -> some View {
        let label = store.state.timeLabel(row)
        return TimeField(label: label.text,
                         time: Binding(get: { store.state.timeDate(row) }, set: { store.send(.timePicked(row, $0)) }),
                         isPlaceholder: label.isPlaceholder, width: width)
    }

    private func schoolField(_ school: SchoolForm) -> some View {
        VStack(alignment: .leading, spacing: sizing.captionGap) {
            CrayonField(store.schoolPlaceholder,
                        text: Binding(get: { school.text }, set: { store.send(.schoolTextChanged($0)) })) {
                if school.picked != nil { KitIcon(.actSchool, size: sizing(48)) }
            }
            .frame(width: layout.schoolFieldWidth)
            .overlay(alignment: .topLeading) {
                // Padding, not offset, so the veil's hole lands on the card itself.
                if school.isListOpen {
                    matches(school).resultVeilHole().padding(.top, sizing.fieldHeight + (keyboardIsUp ? sizing(Spacing.xs) : sizing(Spacing.l)))
                }
            }
            // A pick closes the keyboard (S2s, 2026-11-15); typing keeps it up.
            .keyboardHidden(when: school.picked != nil || school.typedByHand)
            HStack(spacing: sizing(Spacing.xs)) {
                if school.picked != nil { CheckMark(isDone: true, size: 32) }
                Text(store.schoolCaption).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                if school.kind == .school {
                    Button(L10n.tr("hub.data_sources")) { store.send(.dataSourcesTapped) }
                        .crayonType(.caption).foregroundStyle(CrayonColor.link)
                        .padding(.leading, sizing(Spacing.s))
                }
            }
            // Hidden while the list sits on it above the keyboard (S2s, 2026-11-15).
            .opacity(keyboardIsUp && school.isListOpen ? 0 : 1)
        }
        .resultVeilHole()
    }

    /// Up to 8 schools, then always "Not in the list? Type the name" (board S2s), in the shared
    /// result card (layout v14: 6 rows fit, more scroll).
    private func matches(_ school: SchoolForm) -> some View {
        ResultListCard(rows: school.matches.map { entry in
            .init(id: entry.id, title: entry.name, caption: entry.resultCaption(oneLine: listHeight != nil)) {
                store.send(.schoolPicked(entry))
            }
        } + [.init(id: "not-listed", glyph: .plus, title: L10n.tr("s2.school.not_listed")) { store.send(.notInListTapped) }],
        visibleRows: 6, seed: 75, width: layout.grown.controlWidth, fitHeight: listHeight)
    }

    @ViewBuilder private func termsRow(_ row: SchoolForm.TermsRow) -> some View {
        switch row {
        case let .check(isOn):
            Button { store.send(.moeTermsToggled) } label: {
                HStack(spacing: sizing(Spacing.s)) {
                    CheckMark(isDone: isOn, size: 48)
                    Text(store.termsCheckText).crayonType(.body).foregroundStyle(CrayonColor.ink)
                }
            }
            .buttonStyle(.plain)
        case .moe, .own:
            // Shown as the "Terms" text row above.
            EmptyView()
        case let .ask(answer):
            // Spec S2 Terms row: the question, then "Yes" / "Not sure" pills 64 tall, 12 apart. They
            // stay 180 wide: "Not sure" in body 30 runs over a 140 pill's outline (13" check).
            VStack(alignment: .leading, spacing: sizing(Spacing.xs)) {
                Text(store.termsQuestion).crayonType(.caption).foregroundStyle(CrayonColor.ink)
                CrayonTabs(selection: Binding(get: { answer }, set: { if let yes = $0 { store.send(.moeAnswered(yes)) } }),
                           items: [(Optional(true), store.termsYes, nil),
                                   (Optional(false), store.termsNotSure, nil)],
                           itemSize: CGSize(width: 180, height: 64), spacing: Spacing.sm)
            }
        }
    }
}

private struct MedalSide: View {

    @Environment(\.sizing) private var sizing
    let store: StoreOf<SetupFeature>

    var body: some View {
        let captions = store.state.medalCaptions
        VStack(alignment: .leading, spacing: sizing(Spacing.s)) {
            Text(L10n.tr("s2.medals.title")).crayonType(.head)
            medal(.medalGold, L10n.tr("s2.medal.gold"), captions.gold)
            medal(.medalSilver, L10n.tr("s2.medal.silver"), captions.silver)
            medal(.medalBronze, L10n.tr("s2.medal.bronze"), captions.bronze)
        }
        .foregroundStyle(CrayonColor.ink)
    }

    private func medal(_ slot: KitSlot, _ name: String, _ caption: String) -> some View {
        HStack(alignment: .top, spacing: sizing(Spacing.s)) {
            KitIcon(slot, size: sizing(64))
            VStack(alignment: .leading, spacing: 0) {
                Text(name).crayonType(.body, bold: true)
                Text(caption).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - S3 · Getting to school

private struct GoingStep: View {
    let store: StoreOf<SetupFeature>
    @Environment(\.sizing) private var sizing

    var body: some View {
        let grown = GrownupLayout(sizing: sizing)
        // Spec "Several buses": a long list of buses wraps and the rows below move down; the rows
        // scroll inside the card rather than run past it (as C2).
        PaperCard(seed: 81) {
            ScrollColumn(bleed: sizing.drawnBleed) {
                rows.frame(width: grown.editorRowsWidth, alignment: .leading)
            }
        }
        .frame(width: grown.form.width, height: grown.form.height, alignment: .topLeading)
    }

    /// Board S3 (layout v61): Going 180, Stop 323 (caption 405), Buses 459, Walk 543, Ride 627 (one
    /// per bus), the link 801; rows 24 apart between drawn edges (spec "Layout balance").
    @ViewBuilder private var rows: some View {
        if let kid = store.goingKid {
            let going = kid.going
            VStack(alignment: .leading, spacing: sizing.formRowGap) {
                row(L10n.tr("going.label")) {
                    ChoiceCircles(GoingForm.ways.map { way in
                        ChoiceCircles.Choice(id: way.rawValue, picture: KitSlot(rawValue: way.moverPicture),
                                             caption: SetupFeature.State.wayCaption(way), isPicked: going.way == way)
                    }) { id in if let way = Way(rawValue: id) { store.send(.wayPicked(way)) } }
                }
                .captionedRow()
                if going.way == .bus {
                    row(L10n.tr("c2.stop")) {
                        StopSearchField(store: store.scope(state: \.goingSearch, action: \.stopSearch), visibleRows: 6,
                                        listWidth: GrownupLayout(sizing: sizing).controlWidth)
                    }
                    .captionedRow()
                    .zIndex(1)
                    row(L10n.tr("s3.buses")) {
                        VStack(alignment: .leading, spacing: sizing(Spacing.xs)) {
                            if store.hasBusPills {
                                // Boards S3/C2: bus pills 180 × 72, three across, then one pill per bus
                                // that changes ("12 · 34 → 33"), wrapping.
                                PillToggleGrid(controlWidth: GrownupLayout(sizing: sizing).controlWidth) {
                                    ForEach(going.search.servicesAtStop, id: \.self) { service in
                                        PillToggle(service, isOn: going.services.contains(service)) {
                                            store.send(.serviceTapped(service))
                                        }
                                    }
                                    ForEach(store.changePills) { pill in
                                        PillToggle(pill.title, isOn: true, then: pill.then) {
                                            store.send(.changeTapped(pill.index))
                                        }
                                    }
                                }
                            } else {
                                // Board S3: the empty row keeps the pills' 72 slot.
                                Text(L10n.tr("c2.buses.none")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                                    .frame(height: sizing.tabHeight())
                            }
                        }
                    }
                    .drawnRow()
                    stepper(L10n.tr("c2.walk"), text: store.walkText, caption: L10n.tr("s3.walk.caption"),
                            value: going.walk) { store.send(.walkChanged($0)) }
                    ForEach(store.rideRows) { ride in
                        stepper(ride.label, text: ride.text, caption: ride.caption, value: ride.minutes) { store.send(.rideChanged(service: ride.service, minutes: $0)) }
                    }
                    // Board S3 (v61, y 801): "+ A bus that changes…" → C2c, back to S3.
                    row("") { PlusLink(store.changeLink) { store.send(.changeLinkTapped) } }
                } else {
                    stepper(L10n.tr("going.leave"), text: store.leaveText, caption: store.leaveCaptionText,
                            step: 5, value: going.leaveBefore) { store.send(.leaveChanged($0)) }
                }
            }
        }
    }

    /// Board S3 rows hold 72 parts (circles, pills, steppers): 72 × s, never under 56.
    private func row(_ label: String, @ViewBuilder control: () -> some View) -> some View {
        SetupRow(label: label, height: sizing.tabHeight(), control: control)
    }

    private func stepper(_ label: String, text: String, caption: String, step: Int = 1, value: Int,
                         change: @escaping (Int) -> Void) -> some View {
        // Board S3: the shared stepper on the control line, laid out by its drawn box.
        row(label) {
            MinutesStepper(value: text, caption: caption,
                           minus: { change(value - step) }, plus: { change(value + step) })
        }
        .drawnRow()
    }
}

// MARK: - S4 · Almost done

private struct AlmostDoneStep: View {

    @Environment(\.sizing) private var sizing
    let store: StoreOf<SetupFeature>
    let layout: SetupLayout

    /// Board S4 (layout v56): the switch rows on the form card's lines, the picture on the label line
    /// (78) and the words 24 after it, each row as tall as its words and 24 apart (first at 186).
    /// Rows for features not built yet are not listed.
    var body: some View {
        // The rows scroll inside the card to its edge, so the card's padding sits inside the scroll.
        PaperCard(seed: 91) {
            ScrollColumn {
                VStack(alignment: .leading, spacing: layout.grown.sizing.formRowGap) {
                    ForEach(store.settingRows, id: \.setting) { row in
                        SettingRow(title: row.title, caption: row.caption, captionIsWarning: row.isWarning,
                                   isOn: row.isOn, hugs: true, action: { store.send(.settingTapped(row.setting)) }) {
                            picture(row.picture)
                        }
                    }
                }
                .frame(width: layout.grown.editorRowsWidth, alignment: .leading)
                .padding(sizing.cardPadding)
            }
        }
        .environment(\.cardPadding, EdgeInsets())
        .frame(width: layout.grown.form.width, height: layout.length(968 - 148), alignment: .topLeading)
    }

    @ViewBuilder private func picture(_ picture: AppSettingRow.Picture) -> some View {
        switch picture {
        case .lock: LockMark(size: sizing.settingRowPicture)
        case let .kit(name): KitIcon(KitSlot(iconName: name), size: sizing.settingRowPicture)
        }
    }
}

/// Board S4's side column, on its lines: "You're set up" (baseline 212), the kids (263), the school
/// and way rows (pictures 56 centred on their two lines, text at 1002), then the caption.
private struct SummarySide: View {
    @Environment(\.sizing) private var sizing
    let store: StoreOf<SetupFeature>
    let layout: SetupLayout

    var body: some View {
        let rows = summaryRows
        ZStack(alignment: .topLeading) {
            let title = layout.s4Side(864, 184)
            Text(L10n.tr("s4.side.title")).crayonType(.head).place(left: title.x, baseline: title.y)
            let kidsLine = layout.s4Side(864, 235)
            HStack(spacing: sizing(Spacing.sm)) { kids }.place(left: kidsLine.x, baseline: kidsLine.y)
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                let top = layout.s4SummaryTop(index)
                KitIcon(row.slot, size: layout.length(56))
                    .place(topLeft: layout.s4Side(864, top + 11))
                let titleLine = layout.s4Side(936, top + 35)
                Text(row.title).crayonType(.body).lineLimit(1).place(left: titleLine.x, baseline: titleLine.y)
                let detailLine = layout.s4Side(936, top + 67)
                // Spec: a " · " value line wraps at a separator onto 2 lines, never clips.
                SeparatedValueText(row.detail).foregroundStyle(CrayonColor.softText)
                    .frame(width: layout.grown.side.width - detailLine.x, alignment: .leading)
                    .place(left: detailLine.x, baseline: detailLine.y)
            }
        }
        .foregroundStyle(CrayonColor.ink)
        .frame(width: layout.grown.side.width, height: layout.length(872 - 148), alignment: .topLeading)
    }

    private var summaryRows: [(slot: KitSlot, title: String, detail: String)] {
        var rows: [(slot: KitSlot, title: String, detail: String)] = []
        if let school = store.summarySchool { rows.append((.actSchool, school.title, school.hours)) }
        if let way = store.summaryWay { rows.append((KitSlot(iconName: way.picture), way.title, way.detail)) }
        return rows
    }

    @ViewBuilder private var kids: some View {
        ForEach(Array(store.kids.enumerated()), id: \.element.id) { index, kid in
            HStack(alignment: .firstTextBaseline, spacing: sizing(KidFace.gap(for: KidFace.medium))) {
                KidFace(.init(face: kid.face ?? "", colorIndex: kid.colorIndex),
                        size: sizing(KidFace.medium))
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - sizing(4) }
                // Board S4: "Kid A · Kid B".
                Text(index + 1 < store.kids.count ? L10n.tr("hub.about.part", kid.shownName(index: index))
                                                  : kid.shownName(index: index))
                    .crayonType(.body).lineLimit(1)
            }
        }
    }
}

/// A setup form row (C2's look): the label in caption type on one line in the 104–232 column,
/// centred on the control's first line (`height`: an 80 field or a 72 control).
private struct SetupRow<Control: View>: View {
    let label: String
    let height: CGFloat
    let control: Control
    @Environment(\.formLabelWidth) private var labelWidth

    init(label: String, height: CGFloat, @ViewBuilder control: () -> Control) {
        self.label = label
        self.height = height
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // One line; the card's column fits its longest label.
            Text(label).crayonType(.caption, bold: true).foregroundStyle(CrayonColor.softText).lineLimit(1)
                .frame(width: labelWidth ?? 128, height: height, alignment: .leading)
            control.frame(minHeight: height, alignment: .leading)
        }
    }
}
