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
                             anchor: .top, bleed: .cardCorner(touch: Sizing.cornerControlTouch)) {
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
                    .frame(width: grown.side.width, height: grown.action.minY - grown.side.minY - Spacing.s,
                           alignment: .topLeading)
            }
        } primaryAction: { grown in
            VStack(alignment: .leading, spacing: Spacing.xs) {
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
                    CrayonColor.dim.ignoresSafeArea()
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
        .task { await store.send(.task).finish() }
    }

    // MARK: Header

    private func header(_ layout: SetupLayout) -> some View {
        HStack(spacing: layout.grown.titleGap) {
            if store.showsBack {
                RoundButton(glyph: .chevronLeft, accessibilityLabel: L10n.tr("grownup.back")) { store.send(.backTapped) }
            }
            Text(store.title).crayonType(.title).foregroundStyle(CrayonColor.ink).lineLimit(1).layoutPriority(1)
            headerAccessory(layout)
            Spacer(minLength: Spacing.m)
            Text(store.stepText).crayonType(.caption).foregroundStyle(CrayonColor.softText).lineLimit(1).fixedSize()
            StepDots(current: store.step.number)
        }
        // Spec "Header row": the kid tabs stay 72 on every iPad.
        .environment(\.isHeaderRow, true)
    }

    /// S2 and S3: the kid tabs, as State lists them (spec "S3 · Getting there").
    @ViewBuilder private func headerAccessory(_ layout: SetupLayout) -> some View {
        if store.step == .school || store.step == .gettingThere {
            CrayonTabs(selection: Binding(get: { store.selectedKidTab }, set: { store.send(.kidTabTapped($0)) }),
                       items: store.kidTabs.map { tab in
                           (tab.id, tab.name, KidFace.Badge(face: tab.face, colorIndex: tab.colorIndex))
                       },
                       itemSize: layout.kidTab(faceOnly: store.kidTabsAreFaceOnly), spacing: layout.kidTabGap,
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
            VStack(alignment: .leading, spacing: Spacing.m) {
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
                VStack(alignment: .leading, spacing: Spacing.s) {
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
        VStack(alignment: .leading, spacing: FormLines.cardGap) {
            ForEach(Array(store.kids.enumerated()), id: \.element.id) { index, kid in
                PaperCard(seed: 61 + UInt32(index), padding: FormLines.cardPadding) { card(kid, index: index) }
                    .frame(width: layout.grown.form.width, alignment: .topLeading)
                    .cardCorner(size: Sizing.cornerControl) { removeButton(kid) } popover: { removeConfirm(kid, index: index) }
                    .zIndex(store.removeConfirm == kid.id ? 1 : 0)
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                if store.canAddKid {
                    Button { store.send(.addKidTapped) } label: {
                        HStack(spacing: Spacing.s) {
                            RoundButton(glyph: .plus, accessibilityLabel: L10n.tr("s1.add")) {}.size(72).allowsHitTesting(false)
                            Text(L10n.tr("s1.add")).crayonType(.body).foregroundStyle(CrayonColor.link)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Text(L10n.tr("s1.one_child")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
            }
            .padding(.leading, FormLines.cardPadding.leading)
        }
    }

    /// Spec S1 "Remove a kid" (board v54): a round × (48, touch 64) on the card's drawn top-right corner
    /// (`cardCorner`); "Remove {name}?" hangs under it when the card has something typed.
    @ViewBuilder private func removeButton(_ kid: KidEntry) -> some View {
        if store.canRemoveKids {
            let name = kid.trimmedName
            RoundButton(glyph: .close, accessibilityLabel: name.isEmpty ? L10n.tr("s1.remove.label.empty")
                                                                       : L10n.tr("s1.remove.label", name)) {
                store.send(.removeKidTapped(kid.id))
            }
            .size(Sizing.cornerControl)
            .touch(Sizing.cornerControlTouch)
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

    /// Board S1 v56: Name and Colour on the label and control lines; Age and Face on a second
    /// column ending on the right edge, under the first column when it does not fit.
    private var lines: FormLines {
        layout.grown.formLines(secondLabels: [L10n.tr("s1.age"), L10n.tr("s1.face")],
                               secondControlWidth: 2 * sizing.pickedFace + Spacing.sm,
                               firstControlMinimum: CGFloat(KidEntry.colours) * ColourSwatch.frame(sizing)
                                   + CGFloat(KidEntry.colours - 1) * Spacing.sm)
    }

    private func card(_ kid: KidEntry, index: Int) -> some View {
        let badge = KidFace.Badge(face: kid.face ?? "", colorIndex: kid.colorIndex)
        return VStack(alignment: .leading, spacing: sizing.formRowGap) {
            FormRow(L10n.tr("s1.name"), kind: .field, second: L10n.tr("s1.age")) {
                CrayonField(L10n.tr("s1.name.placeholder"),
                            text: Binding(get: { kid.name }, set: { store.send(.nameChanged(kid.id, $0)) })) {
                    KidFace(badge, name: kid.shownName(index: index), size: KidFace.medium)
                }
            } secondControl: {
                CrayonField(L10n.tr("s1.age.placeholder"),
                            text: Binding(get: { kid.ageText }, set: { store.send(.ageChanged(kid.id, $0)) }))
                    .keyboardType(.numberPad)
            }
            FormRow(L10n.tr("s1.colour"), kind: .choice, second: L10n.tr("s1.face")) {
                HStack(spacing: Spacing.sm) {
                    ForEach(0..<KidEntry.colours, id: \.self) { colour in
                        ColourSwatch(colorIndex: colour, isPicked: kid.colorIndex == colour,
                                     accessibilityLabel: SetupFeature.State.colourName(colour)) {
                            store.send(.colourTapped(kid.id, colour))
                        }
                    }
                }
            } secondControl: {
                HStack(spacing: Spacing.sm) {
                    face(.kidGirl, label: L10n.tr("s1.face.girl"), kid: kid)
                    face(.kidBoy, label: L10n.tr("s1.face.boy"), kid: kid)
                }
                .partInset()
            }
        }
        .formLines(lines)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func face(_ slot: KitSlot, label: String, kid: KidEntry) -> some View {
        Button { store.send(.faceTapped(kid.id, slot.rawValue)) } label: {
            // Board S1: each face on a white disc with an ink circle; the pick adds the blue ring.
            // Spec "Part floors": 64 × s, never under 56; the picture keeps its 56 : 64.
            KitIcon(slot, size: layout.grown.sizing.pickedFace * 56 / 64)
                .frame(width: layout.grown.sizing.pickedFace, height: layout.grown.sizing.pickedFace)
                .background { CrayonSurface(.circle, fill: CrayonStyle.paper, marker: .thin, seed: 1650) }
                .overlay {
                    if kid.face == slot.rawValue {
                        Circle().stroke(CrayonColor.pickBlue, lineWidth: 5)
                            .frame(width: layout.grown.sizing.pickedFaceRing, height: layout.grown.sizing.pickedFaceRing)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(kid.face == slot.rawValue ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - S2 · School

private struct SchoolStep: View {
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

    /// Board S2 (layout v11): Goes to 208, School 304, Days 448, Hours 544, Arrive by 680, MOE 792.
    @ViewBuilder private var rows: some View {
        if let kid = store.tabKid {
            let school = kid.school
            VStack(alignment: .leading, spacing: Spacing.m) {
                SetupRow(label: L10n.tr("s2.goes"), height: 72) {
                    CrayonTabs(selection: Binding(get: { kid.goesTo }, set: { if let place = $0 { store.send(.goesToTapped(place)) } }),
                               items: SetupFeature.State.places.map { (Optional($0.0), $0.1, nil) },
                               // 180 on the board; three always fit the control column.
                               itemSize: CGSize(width: layout.grown.sizing.goesToTabWidth, height: 72),
                               spacing: Spacing.sm)
                }
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
            .id(Self.fieldID)
            .zIndex(1)
        row(L10n.tr("s2.days")) {
            // Board S2: 56 circles on a 72 pitch.
            HStack(spacing: Spacing.s) {
                ForEach(Weekday.allCases.sorted(), id: \.self) { day in
                    DayChip(DayText.initial(day), isOn: Binding(get: { school.days.contains(day) },
                                                                set: { _ in store.send(.dayToggled(day)) }), size: 56)
                }
            }
        }
        row(L10n.tr("s2.hours")) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.s) {
                    time(.start, width: 180)
                    MarkerIcon(.arrowRight, size: 40, color: CrayonColor.softText)
                    time(.end, width: 180)
                }
                // The caption's line is kept even when empty, so the rows below stay on their lines.
                Text(school.hoursSource ?? " ").crayonType(.caption).foregroundStyle(CrayonColor.softText)
            }
        }
        if school.kind == .school {
            // One row: Arrive by, then "latest" and the gate's time (both 180 × 80, gap 16).
            row(L10n.tr("s2.arrive_by")) {
                HStack(spacing: Spacing.s) {
                    time(.arriveBy, width: 180)
                    Text(L10n.tr("s2.latest")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    time(.latest, width: 180)
                }
            }
        }
        // Board S2: the MOE row starts on the control column (232).
        if let terms = school.termsRow { termsRow(terms).padding(.leading, layout.grown.labelWidth) }
    }

    private func row(_ label: String, @ViewBuilder control: () -> some View) -> some View {
        SetupRow(label: label, height: 80, control: control)
    }

    private func time(_ row: SetupFeature.TimeRow, width: CGFloat? = nil) -> some View {
        let label = store.state.timeLabel(row)
        return TimeField(label: label.text,
                         time: Binding(get: { store.state.timeDate(row) }, set: { store.send(.timePicked(row, $0)) }),
                         isPlaceholder: label.isPlaceholder, width: width)
    }

    private func schoolField(_ school: SchoolForm) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            CrayonField(store.schoolPlaceholder,
                        text: Binding(get: { school.text }, set: { store.send(.schoolTextChanged($0)) })) {
                if school.picked != nil { KitIcon(.actSchool, size: 48) }
            }
            .frame(width: layout.schoolFieldWidth)
            .overlay(alignment: .topLeading) {
                // Padding, not offset, so the veil's hole lands on the card itself.
                if school.isListOpen {
                    matches(school).resultVeilHole().padding(.top, 80 + (keyboardIsUp ? Spacing.xs : Spacing.l))
                }
            }
            // A pick closes the keyboard (S2s, 2026-11-15); typing keeps it up.
            .keyboardHidden(when: school.picked != nil || school.typedByHand)
            HStack(spacing: Spacing.xs) {
                if school.picked != nil { CheckMark(isDone: true, size: 32) }
                Text(store.schoolCaption).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                if school.kind == .school {
                    Button(L10n.tr("hub.data_sources")) { store.send(.dataSourcesTapped) }
                        .crayonType(.caption).foregroundStyle(CrayonColor.link)
                        .padding(.leading, Spacing.s)
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
                HStack(spacing: Spacing.s) {
                    CheckMark(isDone: isOn, size: 48)
                    Text(L10n.tr("s2.terms.moe")).crayonType(.body).foregroundStyle(CrayonColor.ink)
                }
            }
            .buttonStyle(.plain)
        case .ownDates:
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(L10n.tr("s2.terms.own")).crayonType(.body).foregroundStyle(CrayonColor.ink)
                if let caption = store.termsCaption {
                    Text(caption).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                }
            }
        case let .ask(answer):
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(L10n.tr("s2.terms.ask")).crayonType(.caption).foregroundStyle(CrayonColor.ink)
                CrayonTabs(selection: Binding(get: { answer }, set: { if let yes = $0 { store.send(.moeAnswered(yes)) } }),
                           items: [(Optional(true), L10n.tr("s2.terms.yes"), nil),
                                   (Optional(false), L10n.tr("s2.terms.not_sure"), nil)],
                           itemSize: CGSize(width: 180, height: 64), spacing: Spacing.sm)
            }
        }
    }
}

private struct MedalSide: View {
    let store: StoreOf<SetupFeature>

    var body: some View {
        let captions = store.state.medalCaptions
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(L10n.tr("s2.medals.title")).crayonType(.head)
            medal(.medalGold, L10n.tr("s2.medal.gold"), captions.gold)
            medal(.medalSilver, L10n.tr("s2.medal.silver"), captions.silver)
            medal(.medalBronze, L10n.tr("s2.medal.bronze"), captions.bronze)
        }
        .foregroundStyle(CrayonColor.ink)
    }

    private func medal(_ slot: KitSlot, _ name: String, _ caption: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            KitIcon(slot, size: 64)
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
        PaperCard(seed: 81) {
            rows.frame(width: grown.editorRowsWidth, alignment: .leading)
        }
        .frame(width: grown.form.width, height: grown.form.height, alignment: .topLeading)
    }

    @ViewBuilder private var rows: some View {
        if let kid = store.goingKid {
            let going = kid.going
            VStack(alignment: .leading, spacing: Spacing.m) {
                row(L10n.tr("going.label")) {
                    ChoiceCircles(GoingForm.ways.map { way in
                        ChoiceCircles.Choice(id: way.rawValue, picture: KitSlot(rawValue: way.moverPicture),
                                             caption: SetupFeature.State.wayCaption(way), isPicked: going.way == way)
                    }) { id in if let way = Way(rawValue: id) { store.send(.wayPicked(way)) } }
                }
                if going.way == .bus {
                    row(L10n.tr("c2.stop")) {
                        StopSearchField(store: store.scope(state: \.goingSearch, action: \.stopSearch), visibleRows: 6,
                                        listWidth: GrownupLayout(sizing: sizing).controlWidth)
                    }
                    .zIndex(1)
                    row(L10n.tr("s3.buses")) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            if going.search.servicesAtStop.isEmpty {
                                // Board S3: the empty row keeps the pills' 72 slot.
                                Text(L10n.tr("c2.buses.none")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                                    .frame(height: PillToggle.size.height)
                            } else {
                                // Boards S3/C2: bus pills 180 × 72, three across.
                                PillToggleGrid(controlWidth: GrownupLayout(sizing: sizing).controlWidth) {
                                    ForEach(going.search.servicesAtStop, id: \.self) { service in
                                        PillToggle(service, isOn: going.services.contains(service)) {
                                            store.send(.serviceTapped(service))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    stepper(L10n.tr("c2.walk"), text: store.walkText, caption: L10n.tr("s3.walk.caption"),
                            value: going.walk) { store.send(.walkChanged($0)) }
                    stepper(L10n.tr("c2.ride"), text: store.rideText, caption: L10n.tr("s3.ride.caption"),
                            value: going.ride) { store.send(.rideChanged($0)) }
                } else {
                    stepper(L10n.tr("going.leave"), text: store.leaveText, caption: store.leaveCaption ?? "",
                            step: 5, value: going.leaveBefore) { store.send(.leaveChanged($0)) }
                }
            }
        }
    }

    private func row(_ label: String, @ViewBuilder control: () -> some View) -> some View {
        SetupRow(label: label, height: 72, control: control)
    }

    private func stepper(_ label: String, text: String, caption: String, step: Int = 1, value: Int,
                         change: @escaping (Int) -> Void) -> some View {
        // Board S3: − 72 on 232, the value centred in 304–448, + 72 on 448, the caption on 536.
        row(label) {
            HStack(spacing: 0) {
                RoundButton(glyph: .minus, accessibilityLabel: label) { change(value - step) }.size(72)
                Text(text).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink).frame(width: 144)
                RoundButton(glyph: .plus, accessibilityLabel: label) { change(value + step) }.size(72)
                Text(caption).crayonType(.body).foregroundStyle(CrayonColor.softText).lineLimit(1)
                    .padding(.leading, Spacing.s)
            }
        }
    }
}

// MARK: - S4 · Almost done

private struct AlmostDoneStep: View {
    let store: StoreOf<SetupFeature>
    let layout: SetupLayout

    /// Board S4 (layout v17), placed on its lines on the white form card (64, 176, 818 × 792): rows
    /// 120 tall on a 140 pitch from 216 (picture at 104, the switch ending at 842), then the caption
    /// at 653. Rows for features not built yet are not listed.
    var body: some View {
        PaperCard(seed: 91) { rows }
            .environment(\.cardPadding, EdgeInsets())
            .frame(width: layout.grown.form.width, height: layout.length(968 - 148), alignment: .topLeading)
    }

    /// Spec "Part floors": the board's 140 pitch is a minimum. A taller row (a 2-line caption at its
    /// floor) grows and the rows below move down, at least the 16 token apart; the card scrolls.
    private var rows: some View {
        let origin = layout.s4Main(80, 188)
        return ScrollColumn {
            VStack(alignment: .leading, spacing: max(layout.length(20), Spacing.s)) {
                ForEach(store.settingRows, id: \.setting) { row in
                    SettingRow(title: row.title, caption: row.caption, captionIsWarning: row.isWarning, isOn: row.isOn,
                               action: { store.send(.settingTapped(row.setting)) }) {
                        picture(row.picture)
                    }
                    .frame(width: layout.grown.editorRowsWidth)
                }
            }
            // Layout v56: the rows start on the label line and end on the right edge.
            .padding(.leading, layout.grown.formInset)
            .padding(.top, origin.y)
        }
        .frame(width: layout.grown.form.width, height: layout.length(968 - 148), alignment: .topLeading)
    }

    @ViewBuilder private func picture(_ picture: AppSettingRow.Picture) -> some View {
        switch picture {
        case .lock: LockMark(size: 56)
        case let .kit(name): KitIcon(KitSlot(iconName: name), size: 56)
        }
    }
}

/// Board S4's side column, on its lines: "You're set up" (baseline 212), the kids (263), the school
/// and way rows (pictures 56 centred on their two lines, text at 1002), then the caption.
private struct SummarySide: View {
    let store: StoreOf<SetupFeature>
    let layout: SetupLayout

    var body: some View {
        let rows = summaryRows
        ZStack(alignment: .topLeading) {
            let title = layout.s4Side(864, 184)
            Text(L10n.tr("s4.side.title")).crayonType(.head).place(left: title.x, baseline: title.y)
            let kidsLine = layout.s4Side(864, 235)
            HStack(spacing: Spacing.sm) { kids }.place(left: kidsLine.x, baseline: kidsLine.y)
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
            HStack(alignment: .firstTextBaseline, spacing: KidFace.gap(for: KidFace.medium)) {
                KidFace(.init(face: kid.face ?? "", colorIndex: kid.colorIndex), name: kid.shownName(index: index),
                        size: KidFace.medium)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 4 }
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
            // Spec "Part floors": one line, never shrunk; the card's column fits its longest label.
            Text(label).crayonType(.caption, bold: true).foregroundStyle(CrayonColor.softText).lineLimit(1)
                .frame(width: labelWidth ?? 128, height: height, alignment: .leading)
            control.frame(minHeight: height, alignment: .leading)
        }
    }
}
