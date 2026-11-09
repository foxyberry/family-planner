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

    public init(store: StoreOf<SetupFeature>) {
        self.store = store
    }

    public var body: some View {
        let layout = SetupLayout(sizing: sizing)
        GrownupScreen {
            header(layout)
        } content: { grown in
            HStack(alignment: .top, spacing: grown.gap) {
                main(layout).frame(width: grown.form.width, alignment: .topLeading)
                side.frame(width: grown.side.width, alignment: .topLeading)
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
                    CrayonColor.marker.opacity(0.3).ignoresSafeArea()
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
            headerAccessory
            Spacer(minLength: Spacing.m)
            Text(store.stepText).crayonType(.caption).foregroundStyle(CrayonColor.softText).lineLimit(1).fixedSize()
            StepDots(current: store.step.number)
        }
    }

    @ViewBuilder private var headerAccessory: some View {
        switch store.step {
        case .school:
            CrayonTabs(selection: Binding(get: { store.schoolTab }, set: { store.send(.schoolTabTapped($0)) }),
                       items: store.kids.enumerated().map { index, kid in
                           (kid.id, kid.shownName(index: index), KidFace.Badge(face: kid.face ?? "", colorIndex: kid.colorIndex))
                       })
        default:
            EmptyView()
        }
    }

    // MARK: Main column

    @ViewBuilder private func main(_ layout: SetupLayout) -> some View {
        switch store.step {
        case .family: FamilyStep(store: store, layout: layout)
        case .school: SchoolStep(store: store, layout: layout)
        case .gettingThere: GoingStep(store: store)
        case .almostDone: AlmostDoneStep(store: store, layout: layout)
        }
    }

    // MARK: Side column

    @ViewBuilder private var side: some View {
        switch store.step {
        case .family:
            VStack(alignment: .leading, spacing: Spacing.m) {
                // The kit's home picture only: the family's own home drawing is never used here.
                KitIcon(.home, size: 280).environment(\.kitArt, BundledKitArt(includePrivate: false))
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
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text(L10n.tr("s3.side.title")).crayonType(.head)
                if store.goingKid?.going.way == .bus {
                    Text(L10n.tr("s3.side.leave_in")).crayonType(.body)
                }
                if let times = store.goingTimesCaption {
                    Text(times).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                }
                Text(L10n.tr("s3.side.later")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
            }
            .foregroundStyle(CrayonColor.ink)
        case .almostDone:
            SummarySide(store: store)
        }
    }
}

// MARK: - S1 · Family

private struct FamilyStep: View {
    let store: StoreOf<SetupFeature>
    let layout: SetupLayout

    var body: some View {
        VStack(alignment: .leading, spacing: layout.cardGap) {
            ForEach(Array(store.kids.enumerated()), id: \.element.id) { index, kid in
                PaperCard(seed: 61 + UInt32(index)) { card(kid, index: index) }
                    .frame(width: layout.grown.form.width, height: layout.cardHeight, alignment: .topLeading)
                    .overlay(alignment: .topTrailing) { removeButton(kid, index: index) }
                    .zIndex(store.removeConfirm == kid.id ? 1 : 0)
            }
            VStack(alignment: .leading, spacing: Spacing.xs) {
                if store.canAddKid {
                    Button { store.send(.addKidTapped) } label: {
                        HStack(spacing: Spacing.s) {
                            RoundButton(glyph: .plus, accessibilityLabel: L10n.tr("s1.add")) {}.allowsHitTesting(false)
                            Text(L10n.tr("s1.add")).crayonType(.body).foregroundStyle(CrayonColor.link)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Text(L10n.tr("s1.one_child")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
            }
            .padding(.leading, layout.grown.formInset)
        }
    }

    /// Layout v13 "Remove a kid": a round × (48, touch 64) centred 12 in from the card's top-right
    /// corner, over its edge; "Remove {name}?" points down from it when the card has something typed.
    @ViewBuilder private func removeButton(_ kid: KidEntry, index: Int) -> some View {
        if store.canRemoveKids {
            let name = kid.trimmedName
            RoundButton(glyph: .close, accessibilityLabel: name.isEmpty ? L10n.tr("s1.remove.label.empty")
                                                                       : L10n.tr("s1.remove.label", name)) {
                store.send(.removeKidTapped(kid.id))
            }
            .size(48)
            .frame(width: 64, height: 64)
            .contentShape(Rectangle())
            .offset(x: 20, y: -20)
            .overlay(alignment: .topTrailing) {
                if store.removeConfirm == kid.id {
                    ConfirmCard(title: L10n.tr("s1.remove.confirm", kid.shownName(index: index)), message: nil,
                                cancel: L10n.tr("s1.remove.keep"), confirm: L10n.tr("s1.remove"), isDestructive: true,
                                onCancel: { store.send(.removeCancelled) }, onConfirm: { store.send(.removeConfirmed) })
                        .frame(width: 360)
                        .offset(x: 20, y: 48)
                }
            }
        }
    }

    private func card(_ kid: KidEntry, index: Int) -> some View {
        let badge = KidFace.Badge(face: kid.face ?? "", colorIndex: kid.colorIndex)
        return VStack(alignment: .leading, spacing: layout.cardRowGap) {
            HStack(spacing: 0) {
                FormLabel(L10n.tr("s1.name"))
                CrayonField(L10n.tr("s1.name.placeholder"),
                            text: Binding(get: { kid.name }, set: { store.send(.nameChanged(kid.id, $0)) })) {
                    KidFace(badge, name: kid.shownName(index: index), size: KidFace.medium)
                }
                .frame(width: 352)
                Spacer(minLength: Spacing.s)
                Text(L10n.tr("s1.age")).crayonType(.body).foregroundStyle(CrayonColor.softText)
                    .padding(.trailing, Spacing.s)
                CrayonField(L10n.tr("s1.age.placeholder"),
                            text: Binding(get: { kid.ageText }, set: { store.send(.ageChanged(kid.id, $0)) }))
                    .keyboardType(.numberPad)
                    .frame(width: 112)
            }
            HStack(spacing: 0) {
                FormLabel(L10n.tr("s1.colour"))
                HStack(spacing: Spacing.xs) {
                    ForEach(0..<KidEntry.colours, id: \.self) { colour in
                        ColourSwatch(colorIndex: colour, isPicked: kid.colorIndex == colour,
                                     accessibilityLabel: SetupFeature.State.colourName(colour)) {
                            store.send(.colourTapped(kid.id, colour))
                        }
                    }
                }
                .padding(.leading, -Spacing.xs)
                Spacer(minLength: Spacing.s)
                Text(L10n.tr("s1.face")).crayonType(.body).foregroundStyle(CrayonColor.softText)
                    .padding(.trailing, Spacing.s)
                HStack(spacing: Spacing.sm) {
                    face(.kidGirl, label: L10n.tr("s1.face.girl"), kid: kid)
                    face(.kidBoy, label: L10n.tr("s1.face.boy"), kid: kid)
                }
            }
        }
        .padding(.top, layout.cardTopInset - layout.grown.formInset)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func face(_ slot: KitSlot, label: String, kid: KidEntry) -> some View {
        Button { store.send(.faceTapped(kid.id, slot.rawValue)) } label: {
            KitIcon(slot, size: 64)
                .frame(width: 64, height: 64)
                .overlay {
                    if kid.face == slot.rawValue {
                        Circle().stroke(CrayonColor.pickBlue, lineWidth: 5).frame(width: 72, height: 72)
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
    let store: StoreOf<SetupFeature>
    let layout: SetupLayout

    var body: some View {
        // Exactly the card's inner width, so no row can widen the card.
        PaperCard(seed: 71) {
            rows.frame(width: layout.grown.form.width - 2 * layout.grown.formInset, alignment: .leading)
        }
        .frame(width: layout.grown.form.width)
    }

    /// Board S2 (layout v11): Goes to 208, School 304, Days 448, Hours 544, Arrive by 680, MOE 792.
    @ViewBuilder private var rows: some View {
        if let kid = store.tabKid {
            let school = kid.school
            VStack(alignment: .leading, spacing: Spacing.m) {
                SetupRow(label: L10n.tr("s2.goes"), height: 72) {
                    CrayonTabs(selection: Binding(get: { kid.goesTo }, set: { if let place = $0 { store.send(.goesToTapped(place)) } }),
                               items: SetupFeature.State.places.map { (Optional($0.0), $0.1, nil) },
                               itemSize: CGSize(width: 180, height: 72), spacing: Spacing.sm)
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
            .zIndex(1)
        row(L10n.tr("s2.days")) {
            HStack(spacing: Spacing.xs) {
                ForEach(Weekday.allCases.sorted(), id: \.self) { day in
                    DayChip(DayText.initial(day), isOn: Binding(get: { school.days.contains(day) },
                                                                set: { _ in store.send(.dayToggled(day)) }))
                }
            }
        }
        row(L10n.tr("s2.hours")) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.s) {
                    time(.start)
                    MarkerIcon(.arrowRight, size: 40, color: CrayonColor.softText)
                    time(.end)
                }
                if let source = school.hoursSource {
                    Text(source).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                }
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
        if let terms = school.termsRow { termsRow(terms) }
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
                if school.isListOpen { matches(school).resultVeilHole().offset(y: 80 + Spacing.l) }
            }
            HStack(spacing: Spacing.xs) {
                if school.picked != nil { CheckMark(isDone: true, size: 32) }
                Text(store.schoolCaption).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                if school.kind == .school {
                    Button(L10n.tr("hub.data_sources")) { store.send(.dataSourcesTapped) }
                        .crayonType(.caption).foregroundStyle(CrayonColor.link)
                        .padding(.leading, Spacing.s)
                }
            }
        }
        .resultVeilHole()
    }

    /// Up to 8 schools, then always "Not in the list? Type the name" (board S2s), in the shared
    /// result card (layout v14: 6 rows fit, more scroll).
    private func matches(_ school: SchoolForm) -> some View {
        ResultListCard(rows: school.matches.map { entry in
            .init(id: entry.id, title: entry.name, caption: entry.caption) { store.send(.schoolPicked(entry)) }
        } + [.init(id: "not-listed", glyph: .plus, title: L10n.tr("s2.school.not_listed")) { store.send(.notInListTapped) }],
        visibleRows: 6, seed: 75)
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
                           itemSize: CGSize(width: 140, height: 64), spacing: Spacing.sm)
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
            Text(L10n.tr("s2.medals.later")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
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
            rows.frame(width: grown.form.width - 2 * grown.formInset, alignment: .leading)
        }
        .frame(width: grown.form.width)
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
                        StopSearchField(store: store.scope(state: \.goingSearch, action: \.stopSearch), visibleRows: 6)
                    }
                    .zIndex(1)
                    row(L10n.tr("s3.buses")) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            if going.search.servicesAtStop.isEmpty {
                                Text(L10n.tr("c2.buses.none")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                            } else {
                                LazyVGrid(columns: Array(repeating: GridItem(.fixed(72), spacing: Spacing.sm), count: 7),
                                          alignment: .leading, spacing: Spacing.sm) {
                                    ForEach(going.search.servicesAtStop, id: \.self) { service in
                                        DayChip(service, isOn: Binding(get: { going.services.contains(service) },
                                                                       set: { _ in store.send(.serviceTapped(service)) }))
                                    }
                                }
                                Text(L10n.tr("s3.buses.caption")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                            }
                        }
                    }
                    stepper(L10n.tr("c2.walk"), text: store.walkText, caption: L10n.tr("s3.walk.caption"),
                            value: going.walk) { store.send(.walkChanged($0)) }
                    stepper(L10n.tr("c2.ride"), text: store.rideText, caption: L10n.tr("s3.ride.caption"),
                            value: going.ride) { store.send(.rideChanged($0)) }
                    Text(L10n.tr("s3.footnote")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                        .fixedSize(horizontal: false, vertical: true)
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
        row(label) {
            HStack(spacing: Spacing.m) {
                RoundButton(glyph: .minus, accessibilityLabel: label) { change(value - step) }
                Text(text).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink).frame(width: 112)
                RoundButton(glyph: .plus, accessibilityLabel: label) { change(value + step) }
                Text(caption).crayonType(.body).foregroundStyle(CrayonColor.softText).lineLimit(1)
            }
        }
    }
}

// MARK: - S4 · Almost done

private struct AlmostDoneStep: View {
    let store: StoreOf<SetupFeature>
    let layout: SetupLayout

    var body: some View {
        PaperCard(seed: 91) {
            VStack(alignment: .leading, spacing: layout.settingRowGap) {
                // Notifications appear once the nudge is built; microphone, camera and Screen Time later.
                HStack(spacing: Spacing.m) {
                    LockMark(size: 56)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(L10n.tr("s4.lock")).crayonType(.body, bold: true)
                        Text(L10n.tr("s4.lock.caption")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    }
                    Spacer(minLength: Spacing.s)
                    CheckMark(isDone: true, size: 48)
                    Text(L10n.tr("s4.lock.on")).crayonType(.body)
                }
                .frame(minHeight: layout.settingRow(0).height)
                Text(L10n.tr("s4.skip")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
            }
            .foregroundStyle(CrayonColor.ink)
            .frame(width: layout.grown.form.width - 2 * layout.grown.formInset, alignment: .leading)
        }
        .frame(width: layout.grown.form.width)
    }
}

private struct SummarySide: View {
    let store: StoreOf<SetupFeature>

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(L10n.tr("s4.side.title")).crayonType(.head)
            // The kids' faces 40 and names, as many per line as fit.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Spacing.m) { kids }
                VStack(alignment: .leading, spacing: Spacing.xs) { kids }
            }
            if let school = store.summarySchool {
                summaryRow(.actSchool, school.title, school.hours)
            }
            if let way = store.summaryWay {
                summaryRow(KitSlot(iconName: way.picture), way.title, way.detail)
            }
            Text(L10n.tr("s4.side.later")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
        }
        .foregroundStyle(CrayonColor.ink)
    }

    @ViewBuilder private var kids: some View {
        ForEach(Array(store.kids.enumerated()), id: \.element.id) { index, kid in
            HStack(spacing: KidFace.gap(for: KidFace.medium)) {
                KidFace(.init(face: kid.face ?? "", colorIndex: kid.colorIndex), name: kid.shownName(index: index),
                        size: KidFace.medium)
                Text(kid.shownName(index: index)).crayonType(.body).lineLimit(1)
            }
        }
    }

    private func summaryRow(_ slot: KitSlot, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.s) {
            KitIcon(slot, size: 56)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title).crayonType(.body).lineLimit(2)
                Text(detail).crayonType(.caption).foregroundStyle(CrayonColor.softText)
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
            Text(label).crayonType(.caption, bold: true).foregroundStyle(CrayonColor.softText).lineLimit(1)
                .frame(width: labelWidth ?? 128, height: height, alignment: .leading)
            control.frame(minHeight: height, alignment: .leading)
        }
    }
}
