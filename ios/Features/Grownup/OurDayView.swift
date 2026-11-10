import ComposableArchitecture
import CrayonKit
import DesignSystem
import Domain
import KitArt
import Strings
import SwiftUI

/// G1 · The day on the clock (boards G1, G1c, G1d): drag the times of a kid's day on a real date.
public struct OurDayView: View {
    @Bindable var store: StoreOf<OurDayFeature>

    public init(store: StoreOf<OurDayFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            GrownupScreen {
                header
            } content: { layout in
                if store.showsList { list(layout) } else { clock(layout) }
            } primaryAction: { layout in
                if !store.showsList { saveButton(layout) }
            }
            if store.isConfirmingLeave {
                CrayonColor.dim.ignoresSafeArea()
                    .onTapGesture { store.send(.leaveCancelled) }
                unsavedCard
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: store.haptics.steps)
        .sensoryFeedback(.impact(weight: .medium), trigger: store.haptics.hours)
        .sensoryFeedback(.impact(weight: .heavy), trigger: store.haptics.bumps)
        .task { await store.send(.task).finish() }
    }

    private func clock(_ layout: GrownupLayout) -> some View {
        HStack(alignment: .top, spacing: layout.gap) {
            EditClock(sectors: store.sectors, knobs: store.knobs, dragging: store.dragging,
                      dragOrigin: store.dragOrigin, hub: store.hub,
                      onKnobDrag: { store.send(.knobDragged(index: $0, minute: $1)) },
                      onKnobEnd: { store.send(.knobReleased($0)) },
                      onLockedTap: { store.send(.lockedKnobTapped($0)) },
                      onSliceTap: { store.send(.sliceTapped(start: $0)) },
                      onPlusTap: { store.send(.plusTapped(start: $0)) },
                      onKnobAdjust: { store.send(.knobAdjusted(index: $0, by: $1)) })
                // Board C6: the clock and its hour labels fill the form box (64–882 × 176–968).
                .frame(width: layout.form.width, height: layout.form.height)
                .overlay(alignment: .bottomTrailing) { undoRedo }
                .accessibilityHint(L10n.tr("day.hint"))
            sideColumn(layout)
                .frame(width: layout.side.width, height: layout.action.minY - Spacing.sm * layout.sizing.s
                       - layout.side.minY, alignment: .topLeading)
        }
    }

    private func saveButton(_ layout: GrownupLayout) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            InkButton(L10n.tr("day.save")) { store.send(.saveTapped) }
                .frame(width: layout.side.width)
            if let error = store.saveError {
                Text(error).crayonType(.caption).foregroundStyle(CrayonColor.lateText)
            }
        }
    }

    /// Board G1: Undo and Redo, 72 each, at the clock area's bottom right (722 and 810, y 880);
    /// off at 45 % when there is nothing to take back or put back.
    private var undoRedo: some View {
        HStack(spacing: Spacing.s) {
            RoundButton(glyph: .undo, accessibilityLabel: L10n.tr("day.undo")) { store.send(.undoTapped) }
                .size(72)
                .opacity(store.canUndo ? 1 : 0.45)
                .disabled(!store.canUndo)
            RoundButton(glyph: .redo, accessibilityLabel: L10n.tr("day.redo")) { store.send(.redoTapped) }
                .size(72)
                .opacity(store.canRedo ? 1 : 0.45)
                .disabled(!store.canRedo)
        }
        .padding(.bottom, Spacing.s)
    }

    /// Board G8: Every week and Just once in one card; Add every week / Add once on the side.
    private func list(_ layout: GrownupLayout) -> some View {
        HStack(alignment: .top, spacing: layout.gap) {
            PaperCard(seed: 63) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    ForEach(store.listSections, id: \.title) { section in
                        Text(section.title).crayonType(.head).foregroundStyle(CrayonColor.ink)
                            .padding(.top, Spacing.xs)
                        ForEach(section.rows) { row in
                            Button { store.send(.listRowTapped(row.target)) } label: {
                                HStack(spacing: Spacing.m) {
                                    KitIcon(KitSlot(iconName: row.picture), size: 56)
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text(row.title).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(1)
                                        Text(row.detail).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                    if row.target != .school {
                                        MarkerIcon(.chevronRight, size: 28, color: CrayonColor.softText)
                                    }
                                }
                                .frame(minHeight: 88)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: layout.form.width, height: layout.form.height)
            VStack(alignment: .leading, spacing: Spacing.s) {
                addLink(L10n.tr("list.add_weekly")) { store.send(.addWeeklyTapped) }
                addLink(L10n.tr("list.add_once")) { store.send(.addOnceTapped) }
            }
            .frame(width: layout.side.width, alignment: .topLeading)
        }
    }

    private func addLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                MarkerIcon(.plus, size: 28, color: CrayonColor.ink)
                    .frame(width: 56, height: 56)
                    .crayonBackground(.circle, fill: nil, seed: 1805)
                Text(title).crayonType(.body).foregroundStyle(CrayonColor.link)
            }
            .frame(minHeight: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        // Board G1: the kid tabs after the title; List · Settings at the right end.
        GrownupHeader(title: L10n.tr("day.title"), onBack: { store.send(.backTapped) }) {
            CrayonTabs(selection: Binding(get: { store.kid }, set: { store.send(.kidTabTapped($0)) }),
                       items: store.kids.map { ($0.id, $0.name, KidFace.Badge(face: $0.face, colorIndex: $0.colorIndex)) })
        } trailing: {
            HStack(spacing: Spacing.sm) {
                CrayonTabs(selection: Binding(get: { store.showsList }, set: { _ in store.send(.listTapped) }),
                           items: [(true, L10n.tr("day.list"), nil)])
                Button { store.send(.settingsTapped) } label: {
                    Text(L10n.tr("day.settings")).crayonType(.body).foregroundStyle(CrayonColor.ink)
                        .padding(.horizontal, Spacing.m)
                        .frame(height: 72)
                        .partBackground(.capsule, fill: CrayonStyle.paper, seed: 73)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Board C6 (layout v6): the tabs and the slice card from the top; "Changes start tomorrow." just
    /// above the Save button and the hint above that, placed from the button up. When the hint would
    /// come within 8 of the card (short iPads) it is left out and stays the clock's VoiceOver hint.
    /// Board G1: the day button (382 × 72) over the slice card; the G1c picker opens over the card.
    private func sideColumn(_ layout: GrownupLayout) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            dayButton
            // Board G1: the slice card is a fixed 382 × 440 box (a new slice's form may grow it).
            PaperCard(seed: 61) { card.frame(maxWidth: .infinity, alignment: .leading) }
                .frame(minHeight: 440 * layout.sizing.s, alignment: .top)
                .overlay(alignment: .topTrailing) {
                    if store.pickerStart != nil { dayPicker.offset(y: -Spacing.s) }
                }
            Spacer(minLength: 0)
        }
    }

    /// "Today Mon 9 Nov ⌄" (the today word bold, the date soft); another day reads "Sat 14 Nov".
    private var dayButton: some View {
        Button { store.send(.dayButtonTapped) } label: {
            HStack(spacing: Spacing.sm) {
                if let today = store.dayButtonToday {
                    Text(today).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink)
                    Text(store.dayButtonDate).crayonType(.body).foregroundStyle(CrayonColor.softText)
                } else {
                    Text(store.dayButtonDate).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink)
                }
                Spacer(minLength: 0)
                MarkerIcon(.chevronDown, size: 28, color: CrayonColor.softText)
            }
            .padding(.horizontal, Spacing.m)
            .frame(maxWidth: .infinity, minHeight: 72)
            .partBackground(.capsule, fill: CrayonStyle.paper, seed: 75)
        }
        .buttonStyle(.plain)
    }

    /// Board G1c: the month, ‹ ›, two weeks of date chips (today underlined, the day in sky) and "Today".
    private var dayPicker: some View {
        PaperCard(seed: 77) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                HStack {
                    Text(store.pickerMonth).crayonType(.head).foregroundStyle(CrayonColor.ink)
                    Spacer()
                    RoundButton(glyph: .chevronLeft, accessibilityLabel: L10n.tr("day.picker.earlier")) {
                        store.send(.pickerPageTapped(-1))
                    }
                    .size(64)
                    RoundButton(glyph: .chevronRight, accessibilityLabel: L10n.tr("day.picker.later")) {
                        store.send(.pickerPageTapped(1))
                    }
                    .size(64)
                }
                ForEach(0..<2, id: \.self) { week in
                    HStack(spacing: Spacing.xs) {
                        ForEach(store.pickerDays.dropFirst(7 * week).prefix(7), id: \.self) { day in
                            DateChip(weekday: store.state.pickerWeekday(day), day: day.day, isOn: day == store.day,
                                     isToday: day == store.today, compact: true) {
                                store.send(.pickerDayTapped(day))
                            }
                        }
                    }
                }
                Button { store.send(.pickerTodayTapped) } label: {
                    Text(L10n.tr("day.picker.today")).crayonType(.body, bold: true).foregroundStyle(CrayonColor.link)
                }
                .buttonStyle(.plain)
            }
        }
        // Seven 70-wide chips 8 apart fit inside; "Wed" needs the 70 at the 24 caption size.
        .frame(width: 600)
    }

    /// Board G1d: "Save the changes?", the change in one line, then Save · Don't save · Cancel.
    private var unsavedCard: some View {
        PaperCard(seed: 79) {
            VStack(alignment: .leading, spacing: Spacing.m) {
                Text(L10n.tr("day.unsaved.title")).crayonType(.head).foregroundStyle(CrayonColor.ink)
                if let line = store.unsavedLine {
                    GlyphText(line, glyph: .arrowRight, type: .body, color: CrayonColor.softText)
                }
                HStack(spacing: Spacing.l) {
                    InkButton(L10n.tr("day.unsaved.save"), height: 80) { store.send(.unsavedSaveTapped) }
                        .frame(width: 200)
                    Button { store.send(.leaveConfirmed) } label: {
                        Text(L10n.tr("day.unsaved.discard")).crayonType(.body, bold: true)
                            .foregroundStyle(CrayonColor.lateText)
                    }
                    .buttonStyle(.plain)
                    Button { store.send(.leaveCancelled) } label: {
                        Text(L10n.tr("day.unsaved.cancel")).crayonType(.body, bold: true)
                            .foregroundStyle(CrayonColor.softText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(minHeight: 300, alignment: .topLeading)
        }
        .frame(width: 560)
    }

    @ViewBuilder private var card: some View {
        if let slice = store.newSlice {
            VStack(alignment: .leading, spacing: Spacing.s) {
                CrayonField(L10n.tr("day.new.name"), text: Binding(get: { slice.name },
                                                                   set: { store.newSlice?.name = $0 }))
                // Every picture, three per row in the side card; the grid scrolls inside its 3 rows.
                ScrollView {
                    IconPicker(selection: Binding(get: { slice.iconName.flatMap(KitSlot.init(rawValue:)) },
                                                  set: { if let slot = $0 { store.send(.newSlicePicturePicked(slot.rawValue)) } }),
                               slots: OurDayFeature.pictures, columns: 3)
                }
                .frame(height: 3 * 88 + 2 * Spacing.s)
                InkButton(L10n.tr("day.new.add")) { store.send(.newSliceAddTapped) }
                    .opacity(store.canAddNewSlice ? 1 : 0.4)
                    .disabled(!store.canAddNewSlice)
            }
        } else if let block = store.selectedBlock {
            VStack(alignment: .leading, spacing: Spacing.s) {
                HStack(spacing: Spacing.s) {
                    if block.kind != .free { KitIcon(KitSlot(iconName: block.iconName), size: 64) }
                    Text(block.title).crayonType(.head).foregroundStyle(CrayonColor.ink).lineLimit(1)
                }
                // Spec "Edit scope": This day / All days under the title.
                CrayonTabs(selection: Binding(get: { store.saveScope }, set: { store.send(.scopeTapped($0)) }),
                           items: [(OurDayFeature.Scope.thisDay, L10n.tr("day.scope.this"), nil),
                                   (.allDays, L10n.tr("day.scope.all"), nil)], compact: true)
                    .fixedSize(horizontal: false, vertical: true)
                timeRow(L10n.tr("day.starts"), label: store.startLabel ?? "", date: store.startDate) {
                    store.send(.startPicked($0))
                }
                timeRow(L10n.tr("day.ends"), label: store.endLabel ?? "", date: store.endDate) {
                    store.send(.endPicked($0))
                }
                if let message = store.message {
                    Text(message).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if store.canMakeFree {
                    Button { store.send(.makeFreeTapped) } label: {
                        Text(L10n.tr("day.make_free")).crayonType(.body).bold().foregroundStyle(CrayonColor.lateText)
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            Text(store.message ?? L10n.tr("day.pick")).crayonType(.body).foregroundStyle(CrayonColor.softText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func timeRow(_ title: String, label: String, date: Date, set: @escaping (Date) -> Void) -> some View {
        HStack(spacing: Spacing.s) {
            Text(title).crayonType(.caption).foregroundStyle(CrayonColor.softText).frame(width: 80, alignment: .leading)
            TimeField(label: label, time: Binding(get: { date }, set: set)).frame(width: 170)
        }
    }
}
