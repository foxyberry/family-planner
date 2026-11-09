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
            GrownupScreen {
                header
            } content: { layout in
                HStack(alignment: .top, spacing: layout.gap) {
                    // Exactly the card's inner width, so no row can widen the card past 64 … 882.
                    PaperCard(seed: 31) { form.frame(width: layout.form.width - 2 * layout.formInset, alignment: .leading) }
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
                        .opacity(store.canSave ? 1 : 0.4)
                        .disabled(!store.canSave)
                    if let error = store.saveError {
                        Text(error).crayonType(.caption).foregroundStyle(CrayonColor.lateText)
                    }
                }
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
            if store.form.repeats == .weekly { weeklyRows } else { onceRows }
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
        // Labels from 104, controls on 232 (GrownupLayout, boards C3 / C4 / E5). A problem caption
        // hangs under its control without moving the rows below off their lines.
        return HStack(alignment: .center, spacing: 0) {
            FormLabel(label)
            control()
                .overlay(alignment: .bottomLeading) {
                    if let shown {
                        Text(shown.message).crayonType(.caption).foregroundStyle(CrayonColor.lateText)
                            .fixedSize()
                            .alignmentGuide(.bottom) { $0[.top] - 2 }
                    }
                }
        }
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
                TimeField(label: store.startLabel, time: Binding(get: { store.startTime }, set: { store.send(.startPicked($0)) }))
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
        row("", problem: .days) {
            HStack(spacing: Spacing.sm) {
                ForEach(Weekday.allCases.sorted(), id: \.self) { day in
                    DayChip(DayText.initial(day), isOn: Binding(get: { store.form.days.contains(day) },
                                                                set: { _ in store.send(.dayToggled(day)) }))
                }
            }
        }
        row("") {
            checkbox(L10n.tr("editor.skip_holidays"), isOn: store.form.skipsHolidays) { store.form.skipsHolidays.toggle() }
        }
        goingRows
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
        goingRows
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
            Text(store.everyTitle).crayonType(.head).foregroundStyle(CrayonColor.ink)
            Text(L10n.tr("editor.weekly.changes")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
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
                Text(L10n.tr("editor.remove_series")).crayonType(.head).foregroundStyle(CrayonColor.lateText)
                    .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Text(L10n.tr("editor.removed_hint")).crayonType(.caption)
                .foregroundStyle(CrayonColor.softText)
        }
    }

    // MARK: Side column (preview)

    private func sideColumn(_ preview: FormPreview) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(preview.heading).crayonType(.head).foregroundStyle(CrayonColor.ink)
            // Boards C3/C4: rows 72 tall on an 80 pitch; C4's "Just this day" note comes after them.
            ForEach(Array(preview.rows.enumerated()), id: \.offset) { _, row in
                PreviewRow(time: row.time, isNew: row.isNew) { previewLabel(row.slot, bold: row.isNew) }
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

    private func previewLabel(_ slot: Slot, bold: Bool) -> some View {
        HStack(spacing: Spacing.sm) {
            KitIcon(KitSlot(iconName: slot.iconName), size: 48)
            Text(slot.title).crayonType(bold ? .head : .body).foregroundStyle(CrayonColor.ink).lineLimit(1)
        }
    }
}
