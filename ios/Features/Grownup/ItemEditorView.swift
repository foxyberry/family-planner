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
            } content: { grid in
                HStack(alignment: .top, spacing: GridMetrics.gutter) {
                    PaperCard(seed: 31) { form.padding(Spacing.m) }
                        .frame(width: grid.span(8))
                    Group {
                        if store.isEditingWeekly { weeklySide } else if let preview = store.preview {
                            sideColumn(preview)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } primaryAction: { grid in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    InkButton(store.primaryTitle) { store.send(.saveTapped) }
                        .frame(width: grid.span(4))
                        .opacity(store.canSave ? 1 : 0.4)
                        .disabled(!store.canSave)
                    if let error = store.saveError {
                        Text(error).crayonType(.caption).foregroundStyle(CrayonColor.lateText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
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
        GrownupHeader(title: store.title, caption: "Grown-ups only · behind the parent lock",
                      onBack: { store.send(.backTapped) })
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
            row("Name", problem: .name) { CrayonField("Name", text: $store.form.name).frame(width: 520) }
            row("When", problem: .when) { whenRow }
            if !store.isEditingWeekly {
                row("Repeat") {
                    CrayonTabs(selection: Binding(get: { store.form.repeats }, set: { store.send(.repeatChanged($0)) }),
                               items: [(ItemForm.Repeat.once, "Just once", nil), (.weekly, "Every week", nil)])
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

    private func row(_ label: String, problem row: FormRow? = nil, @ViewBuilder control: () -> some View)
        -> some View {
        let shown = row.flatMap { store.state.problem(for: $0) }
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
        CrayonTabs(selection: Binding(get: { store.form.audience }, set: { store.send(.audienceTapped($0)) }),
                   items: store.audienceTabs.map { ($0.audience, $0.title, $0.colorIndex.map(CrayonColor.kid)) })
    }

    private var whenRow: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.s) {
                TimeField(time: Binding(get: { store.startTime }, set: { store.send(.startPicked($0)) }))
                Image(systemName: "arrow.right").crayonType(.body).fontWeight(.bold)
                    .foregroundStyle(CrayonColor.softText)
                TimeField(time: Binding(get: { store.endTime }, set: { store.send(.endPicked($0)) }))
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
        row("", problem: .days) {
            HStack(spacing: Spacing.xs) {
                ForEach(Weekday.allCases.sorted(), id: \.self) { day in
                    DayChip(DayText.initial(day), isOn: Binding(get: { store.form.days.contains(day) },
                                                                set: { _ in store.send(.dayToggled(day)) }))
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
                    .opacity(store.canPageEarlier ? 1 : 0.3)
                ForEach(store.dateChips, id: \.day) { chip in
                    DateChip(weekday: chip.weekday, day: chip.day.day, isOn: chip.isOn) {
                        store.send(.dateTapped(chip.day))
                    }
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
            Text(store.everyTitle).crayonType(.head).foregroundStyle(CrayonColor.ink)
            Text("Changes start from the next one.").crayonType(.caption).foregroundStyle(CrayonColor.softText)
            if let title = store.skipRowTitle {
                Button { store.send(.skipRowTapped) } label: {
                    Text(title).crayonType(.body)
                        .foregroundStyle(store.skipRowIsUndo ? CrayonColor.link : CrayonColor.ink)
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

    // MARK: Side column (preview)

    private func sideColumn(_ preview: FormPreview) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(preview.heading).crayonType(.head).foregroundStyle(CrayonColor.ink)
            if let note = preview.note {
                Text(note)
                    .crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(preview.rows.enumerated()), id: \.offset) { _, row in
                if row.isNew {
                    TodayRow(leading: row.time) { previewLabel(row.slot, bold: true) }
                } else {
                    ListRow(leading: row.time) { previewLabel(row.slot, bold: false) }
                }
            }
            if let summary = preview.summary {
                Text(summary).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func previewLabel(_ slot: Slot, bold: Bool) -> some View {
        HStack(spacing: Spacing.s) {
            KitIcon(KitSlot(iconName: slot.iconName), size: 48)
            Text(slot.title).crayonType(bold ? .head : .body).foregroundStyle(CrayonColor.ink).lineLimit(1)
        }
    }
}
