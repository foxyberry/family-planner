import ComposableArchitecture
import CrayonKit
import DesignSystem
import Domain
import KitArt
import ScheduleStore
import SwiftUI

/// Add to the day / edit an item (boards C3, C4, C3k, E5).
public struct ItemEditorView: View {
    @Bindable var store: StoreOf<ItemEditorFeature>
    @Environment(\.relockCaption) private var relockCaption

    /// The pictures offered under "What" (the kit's activity pictures).
    static let pictures: [KitSlot] = [.actSwim, .actArt, .actMusic, .actPiano, .actDance, .actFootball, .actStory,
                                      .actCCA, .actPlay, .homework, .doctor, .cake]

    public init(store: StoreOf<ItemEditorFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            GrownupScreen {
                header
            } content: {
                HStack(alignment: .top, spacing: Spacing.m) {
                    PaperCard(seed: 31) { form.padding(Spacing.m) }
                        .frame(width: 818)
                    Group {
                        if case .editWeekly = store.mode { weeklySide } else { sideColumn }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } primaryAction: {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    InkButton(store.primaryTitle) { store.send(.saveTapped) }
                        .frame(width: 382)
                        .opacity(store.problem == nil && !store.isSaving ? 1 : 0.4)
                        .disabled(store.problem != nil || store.isSaving)
                    if let error = store.saveError {
                        Text(error).crayonType(.caption).foregroundStyle(CrayonColor.lateText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if let title = store.confirmTitle {
                CrayonColor.marker.opacity(0.3).ignoresSafeArea()
                ConfirmCard(title: title, message: store.confirmMessage,
                            cancel: store.confirm == .leave ? "Keep editing" : "Keep",
                            confirm: store.confirm == .leave ? "Leave" : "Remove",
                            isDestructive: store.confirm != .leave,
                            onCancel: { store.send(.confirmCancelled) }, onConfirm: { store.send(.confirmAccepted) })
            }
        }
        .background(CrayonColor.paper.ignoresSafeArea())
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .task { await store.send(.task).finish() }
    }

    private var header: some View {
        HStack(spacing: Spacing.m) {
            RoundButton(systemImage: "chevron.left", accessibilityLabel: "Back") { store.send(.backTapped) }
            Text(store.title).crayonType(.title).foregroundStyle(CrayonColor.ink).lineLimit(1)
            Spacer()
            Text(relockCaption ?? "Grown-ups only · behind the parent lock").crayonType(.caption)
                .foregroundStyle(relockCaption == nil ? CrayonColor.softText : CrayonColor.hurry)
        }
    }

    // MARK: Form

    private var form: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            row("For") { audienceTabs }
            row("What") {
                IconPicker(selection: Binding(get: { store.form.iconName.flatMap(KitSlot.init(rawValue:)) },
                                              set: { if let slot = $0 { store.send(.picturePicked(slot.rawValue)) } }),
                           slots: Self.pictures)
            }
            row("Name", problem: .noName) { CrayonField("Name", text: $store.form.name).frame(width: 520) }
            row("When", problems: [.endsBeforeStart, .timePassed]) { whenRow }
            if case .editWeekly = store.mode {} else {
                row("Repeat") {
                    CrayonTabs(selection: Binding(get: { store.form.repeats == .once ? 0 : 1 },
                                                  set: { store.send(.repeatChanged($0 == 0 ? .once : .weekly)) }),
                               items: [(0, "Just once", nil), (1, "Every week", nil)])
                }
            }
            if store.form.repeats == .weekly { weeklyRows } else { onceRows }
            if case .editOnce = store.mode {
                Button { store.send(.removeTapped) } label: {
                    Text("Remove \(store.original.name)").crayonType(.head).foregroundStyle(CrayonColor.lateText)
                        .frame(height: 88)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func row(_ label: String, problem: FormProblem? = nil, problems: [FormProblem] = [],
                     @ViewBuilder control: () -> some View) -> some View {
        let shown = store.problem.flatMap { ([problem].compactMap { $0 } + problems).contains($0) ? $0 : nil }
        return HStack(alignment: .top, spacing: Spacing.m) {
            Text(label).crayonType(.body).foregroundStyle(CrayonColor.softText).frame(width: 120, alignment: .leading)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                control()
                if let shown {
                    Text(shown.message).crayonType(.caption).foregroundStyle(CrayonColor.lateText)
                }
            }
        }
    }

    private var audienceTabs: some View {
        let kids = store.snapshot?.kids ?? []
        let items: [(String, String, Color?)] = kids.map {
            ($0.id.uuidString, $0.name, CrayonColor.kidPalette[$0.colorIndex % CrayonColor.kidPalette.count])
        } + (kids.count > 1 ? [("both", "Both", nil)] : [])
        let selected: String = switch store.form.audience {
        case let .kid(id): id.uuidString
        case .both: "both"
        }
        return CrayonTabs(selection: Binding(get: { selected }, set: { value in
            store.form.audience = value == "both" ? .both : .kid(UUID(uuidString: value)!)
        }), items: items)
    }

    private var whenRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.s) {
                TimeField(time: minuteBinding(\.start))
                Image(systemName: "arrow.right").font(.system(size: 28, weight: .bold))
                    .foregroundStyle(CrayonColor.softText)
                TimeField(time: minuteBinding(\.end))
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

    /// Minutes in the form, shown in a `TimeField` as a time on the form's day.
    private func minuteBinding(_ keyPath: WritableKeyPath<ItemForm, Int>) -> Binding<Date> {
        let calendar = store.calendar
        let day = store.today
        return Binding(
            get: { day.date(minute: store.form[keyPath: keyPath], calendar: calendar) },
            set: { date in
                let parts = calendar.dateComponents([.hour, .minute], from: date)
                var form = store.form
                form[keyPath: keyPath] = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                store.form = form
            }
        )
    }

    @ViewBuilder private var weeklyRows: some View {
        row("", problem: .noDay) {
            HStack(spacing: Spacing.xs) {
                ForEach(Weekday.allCases.sorted(), id: \.self) { day in
                    DayChip(String(DayText.shortName(day).prefix(1)),
                            isOn: Binding(get: { store.form.days.contains(day) }, set: { on in
                                var days = store.form.days
                                if on { days.insert(day) } else { days.remove(day) }
                                store.form.days = days
                            }))
                }
            }
        }
        row("") {
            checkbox("Skip school holidays", isOn: store.form.skipsHolidays) { store.form.skipsHolidays.toggle() }
        }
    }

    @ViewBuilder private var onceRows: some View {
        row("") {
            HStack(spacing: Spacing.s) {
                RoundButton(systemImage: "chevron.left", accessibilityLabel: "Earlier") { store.send(.datePageTapped(-1)) }
                    .opacity(store.datePage == 0 ? 0.3 : 1)
                ForEach(store.visibleDates, id: \.self) { day in
                    DateChip(weekday: DayText.shortName(day.weekday(store.calendar)), day: day.day,
                             isOn: store.form.date == day) { store.send(.dateTapped(day)) }
                }
                RoundButton(systemImage: "chevron.right", accessibilityLabel: "Later") { store.send(.datePageTapped(1)) }
            }
        }
        row("") {
            checkbox("A star on the clock that day", isOn: store.form.showsStar) { store.form.showsStar.toggle() }
        }
    }

    private func checkbox(_ title: String, isOn: Bool, toggle: @escaping () -> Void) -> some View {
        Button(action: toggle) {
            HStack(spacing: Spacing.s) {
                CheckMark(isDone: isOn, size: 48)
                Text(title).crayonType(.body).foregroundStyle(CrayonColor.ink)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: Side column (every-week item, board E5)

    private var weeklySide: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(Self.everyTitle(store.form.days)).crayonType(.head).foregroundStyle(CrayonColor.ink)
            Text("Changes start from the next one.").crayonType(.caption).foregroundStyle(CrayonColor.softText)
            if let title = store.skipRowTitle {
                Button { store.send(store.skippedDay == nil ? .skipNextTapped : .undoSkipTapped) } label: {
                    Text(title).crayonType(.body)
                        .foregroundStyle(store.skippedDay == nil ? CrayonColor.ink : CrayonColor.link)
                        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Button { store.send(.removeSeriesTapped) } label: {
                Text("Remove every week").crayonType(.head).foregroundStyle(CrayonColor.lateText)
                    .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Text("Removed by mistake? Add it back from Our kids.").crayonType(.caption)
                .foregroundStyle(CrayonColor.softText)
        }
    }

    /// "Every Mon and Wed", "Every Mon, Wed and Fri", "Every school day".
    static func everyTitle(_ days: Set<Weekday>) -> String {
        if days == Weekday.schoolDays { return "Every school day" }
        let names = days.sorted().map(DayText.shortName)
        guard names.count > 1 else { return "Every \(names.first ?? "")" }
        return "Every " + names.dropLast().joined(separator: ", ") + " and " + names.last!
    }

    // MARK: Side column (preview)

    private var previewKid: Kid? {
        let kids = store.snapshot?.kids ?? []
        if case let .kid(id) = store.form.audience { return kids.first { $0.id == id } }
        return kids.first
    }

    private var previewDay: Day {
        guard store.form.repeats == .weekly, let first = store.form.days.sorted().first else { return store.form.date }
        return (0..<7).lazy.map { store.today.adding(days: $0, calendar: store.calendar) }
            .first { $0.weekday(store.calendar) == first } ?? store.today
    }

    private var sideColumn: some View {
        let day = previewDay
        let isBoth = store.form.audience == .both
        let weekday = DayText.name(day.weekday(store.calendar))
        let heading = store.form.repeats == .weekly
            ? (isBoth ? weekday : "\(previewKid?.name ?? "")'s \(weekday)")
            : DayText.long(day, calendar: store.calendar)
        return VStack(alignment: .leading, spacing: Spacing.s) {
            Text(heading).crayonType(.head).foregroundStyle(CrayonColor.ink)
            if store.form.repeats == .once {
                let who = isBoth ? "both kids" : previewKid?.name ?? ""
                Text("Just this day, for \(who). It leaves the clock at midnight.")
                    .crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(previewSlots(day).enumerated()), id: \.offset) { _, entry in
                if entry.isNew {
                    TodayRow(leading: TimeText.clock(entry.slot.start)) { previewLabel(entry.slot, bold: true) }
                } else {
                    ListRow(leading: TimeText.clock(entry.slot.start)) { previewLabel(entry.slot, bold: false) }
                }
            }
            if let summary = store.form.summaryCaption(today: store.today, calendar: store.calendar) {
                Text(summary).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func previewLabel(_ slot: Slot, bold: Bool) -> some View {
        HStack(spacing: Spacing.s) {
            KitIcon(KitSlot(rawValue: slot.iconName) ?? .actPlay, size: 48)
            Text(slot.title).crayonType(bold ? .head : .body).foregroundStyle(CrayonColor.ink).lineLimit(1)
        }
    }

    private func previewSlots(_ day: Day) -> [(slot: Slot, isNew: Bool)] {
        guard let snapshot = store.snapshot, let kid = previewKid else { return [] }
        let id = store.editingItem?.id ?? UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let draft = store.form.item(id: id, today: store.today)
        let items = snapshot.items.filter { $0.id != id } + (store.problem == nil ? [draft] : [])
        return DayPlanner.slots(on: day, kid: kid, routines: snapshot.routines, items: items, holidays: store.holidays,
                                calendar: store.calendar)
            .filter { $0.kind != .sleep }
            .map { slot in
                let isNew = slot.source == .weekly(id) || slot.source == .once(id)
                return (slot, isNew)
            }
    }
}
