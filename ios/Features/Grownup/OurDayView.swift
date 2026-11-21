import ComposableArchitecture
import CrayonKit
import DesignSystem
import Domain
import KitArt
import Strings
import SwiftUI

/// G1 · The day on the clock (boards G1, G1c, G1d, G1e): a kid's day and its items on a real date,
/// edited through one slice card.
public struct OurDayView: View {
    @Bindable var store: StoreOf<OurDayFeature>
    @Environment(\.sizing) private var sizing

    public init(store: StoreOf<OurDayFeature>) {
        self.store = store
    }

    public var body: some View {
        ZStack {
            // Spec "Scrolling on G1": the header and the clock never scroll; the side column and the
            // List card scroll on their own.
            GrownupScreen(scrolls: false) {
                header
            } content: { layout in
                if store.showsList { list(layout) } else { clock(layout) }
            } primaryAction: { layout in
                if !store.showsList { saveButton(layout) }
            }
            if store.isConfirmingLeave {
                CrayonColor.dim.fullBleed()
                    .onTapGesture { store.send(.leaveCancelled) }
                // Board G1d: the shared ConfirmCard, its line's arrow drawn inline (design session, 2026-11-14).
                ConfirmCard(title: L10n.tr("day.unsaved.title"), message: store.unsavedLine, messageGlyph: .arrowRight,
                            cancel: L10n.tr("day.unsaved.cancel"), confirm: L10n.tr("day.unsaved.save"),
                            isDestructive: false, onCancel: { store.send(.leaveCancelled) },
                            onConfirm: { store.send(.unsavedSaveTapped) })
            }
            if let title = store.removeTitle {
                // Spec C6 "One card": "Remove {Name} every week?" / "Remove {Name}?", Remove · Keep.
                CrayonColor.dim.fullBleed()
                    .onTapGesture { store.send(.removeCancelled) }
                ConfirmCard(title: title, message: nil, cancel: store.removeKeep, confirm: store.removeAccept,
                            isDestructive: true, onCancel: { store.send(.removeCancelled) },
                            onConfirm: { store.send(.removeConfirmed) })
            }
            if store.fromWhen != nil {
                CrayonColor.dim.fullBleed()
                    .onTapGesture { store.send(.fromWhenCancelTapped) }
                FromWhenCard(title: L10n.tr("from_when.title"), tabs: store.fromWhenTabs,
                             selection: Binding(get: { store.fromWhen ?? .today }, set: { store.send(.fromWhenPicked($0)) }),
                             dateChoice: ItemEditorFeature.FromWhen.date, dateLabel: store.fromWhenDateLabel,
                             date: Binding(get: { store.fromWhenDateValue }, set: { store.send(.fromWhenDatePicked($0)) }),
                             caption: nil, save: L10n.tr("from_when.save"), cancel: L10n.tr("from_when.cancel"),
                             onSave: { store.send(.fromWhenSaveTapped) }, onCancel: { store.send(.fromWhenCancelTapped) })
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
                      onSliceTap: { store.send(.sliceTapped(start: $0)) },
                      onPlusTap: { store.send(.plusTapped(start: $0)) },
                      addButtons: store.addButtons, onAddBetween: { store.send(.addBetweenTapped($0)) })
                // Board G1 (layout v32): the clock centred at (410, 549), 30 left of and 9 above the
                // form box's middle (440, 558), so its hour labels start at x 30 as on the home clock.
                .offset(x: -30 * layout.sizing.s, y: -9 * layout.sizing.s)
                .frame(width: layout.form.width, height: layout.form.height)
                // Undo / Redo at 656 and 744 (y 880), 24 in from the form box's right edge.
                .overlay(alignment: .bottomTrailing) { undoRedo.padding(.trailing, 24 * layout.sizing.s) }
            sideColumn(layout)
                .frame(width: layout.side.width, height: layout.action.minY - sizing(Spacing.sm)
                       - layout.side.minY, alignment: .topLeading)
        }
        // Board G1c: the picker opens under the day button, over the card; a tap outside closes it.
        .overlay(alignment: .topTrailing) {
            if store.pickerStart != nil {
                ZStack(alignment: .topTrailing) {
                    Color.clear.contentShape(Rectangle()).onTapGesture { store.send(.pickerClosed) }
                    DayPickerCard(month: store.pickerMonth, weeks: store.pickerWeeks,
                                  today: L10n.tr("day.picker.today"), onPage: { store.send(.pickerPageTapped($0)) },
                                  onPick: { store.send(.pickerChipTapped($0)) }, onToday: { store.send(.pickerTodayTapped) })
                        .padding(.top, sizing(72 + Spacing.s))
                }
            }
        }
    }

    private func saveButton(_ layout: GrownupLayout) -> some View {
        VStack(alignment: .leading, spacing: sizing(Spacing.xs)) {
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
        HStack(spacing: sizing(Spacing.s)) {
            RoundButton(glyph: .undo) { store.send(.undoTapped) }
                .size(72)
                .opacity(store.canUndo ? 1 : 0.45)
                .disabled(!store.canUndo)
            RoundButton(glyph: .redo) { store.send(.redoTapped) }
                .size(72)
                .opacity(store.canRedo ? 1 : 0.45)
                .disabled(!store.canRedo)
        }
        .padding(.bottom, sizing(Spacing.s))
    }

    /// Board G8 (layout v36): the sections in one card; one "Add" on the side. A long title or caption
    /// wraps to two lines (the row grows from 88 to 136, picture and › stay centred), then ends in "…".
    private func list(_ layout: GrownupLayout) -> some View {
        HStack(alignment: .top, spacing: layout.gap) {
            // Board G8: the card stays put; its rows scroll under its top edge.
            PaperCard(seed: 63) {
                ScrollColumn {
                    VStack(alignment: .leading, spacing: sizing(Spacing.xs)) {
                        ForEach(store.listSections, id: \.title) { section in
                            Text(section.title).crayonType(.head).foregroundStyle(CrayonColor.ink)
                                .padding(.top, sizing(Spacing.xs))
                            ForEach(section.rows) { row in
                                Button { store.send(.listRowTapped(row.target)) } label: {
                                    HStack(spacing: sizing(Spacing.m)) {
                                        KitIcon(KitSlot(iconName: row.picture), size: sizing(56))
                                        VStack(alignment: .leading, spacing: 0) {
                                            Text(row.title).crayonType(.body).foregroundStyle(CrayonColor.ink)
                                                .lineLimit(2).truncationMode(.tail)
                                                .fixedSize(horizontal: false, vertical: true)
                                            Text(row.detail).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                                                .lineLimit(2).truncationMode(.tail)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        Spacer(minLength: 0)
                                        if row.target != .school {
                                            MarkerIcon(.chevronRight, size: sizing(28), color: CrayonColor.softText)
                                        }
                                    }
                                    .frame(minHeight: sizing(88))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(width: layout.form.width, height: layout.form.height)
            ScrollColumn {
                addLink(L10n.tr("list.add")) { store.send(.addTapped) }
            }
            .frame(width: layout.side.width, height: layout.form.height, alignment: .topLeading)
        }
    }

    private func addLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: sizing(Spacing.s)) {
                MarkerIcon(.plus, size: sizing(28), color: CrayonColor.ink)
                    .frame(width: sizing(56), height: sizing(56))
                    .crayonBackground(.circle, fill: nil, seed: 1805)
                Text(title).crayonType(.body).foregroundStyle(CrayonColor.link)
            }
            .frame(minHeight: sizing(72))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        // Board G1: the kid tabs after the title; List · Settings at the right end.
        GrownupHeader(title: L10n.tr("day.title"), caption: store.headerCaption,
                      onBack: { store.send(.backTapped) }) {
            CrayonTabs(selection: Binding(get: { store.kid }, set: { store.send(.kidTabTapped($0)) }),
                       items: store.kids.map { ($0.id, $0.name, KidFace.Badge(face: $0.face, colorIndex: $0.colorIndex)) })
        } trailing: {
            HStack(spacing: sizing(Spacing.sm)) {
                CrayonTabs(selection: Binding(get: { store.showsList }, set: { _ in store.send(.listTapped) }),
                           items: [(true, L10n.tr("day.list"), nil)])
                Button { store.send(.settingsTapped) } label: {
                    Text(L10n.tr("day.settings")).crayonType(.body).foregroundStyle(CrayonColor.ink)
                        .padding(.horizontal, sizing(Spacing.m))
                        .frame(height: sizing(72))
                        .partBackground(.capsule, fill: CrayonStyle.paper, seed: 73)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Board C6 (layout v6): the tabs and the slice card from the top; "Changes start tomorrow." just
    /// above the Save button and the hint above that, placed from the button up. When the hint would
    /// come within 8 of the card (short iPads) it is left out.
    /// Board G1: the day button (382 × 72) over the slice card; the G1c picker opens over the card.
    private func sideColumn(_ layout: GrownupLayout) -> some View {
        VStack(alignment: .leading, spacing: sizing(Spacing.m)) {
            DayButton(today: store.dayButtonToday, date: store.dayButtonDate) { store.send(.dayButtonTapped) }
            // Board G1: the slice card is a fixed 382 × 440 box (a new slice's form may grow it), its
            // contents 24 inside (954 … 1288), so This day / All days fit and the card keeps the column.
            // The day button stays at the top and Save at the foot; only the card scrolls between them.
            ScrollColumn {
                PaperCard(seed: 61) { card.frame(maxWidth: .infinity, alignment: .leading) }
                    .environment(\.cardPadding, EdgeInsets(all: sliceCardInset))
                    .frame(width: layout.side.width)
            }
        }
    }

    @ViewBuilder private var card: some View {
        if let slice = store.newSlice {
            // Board G1f: scope tabs (just once or every week), seven pictures and "More"
            // (4 per row), the name, the times.
            VStack(alignment: .leading, spacing: sizing(Spacing.s)) {
                scopeTabs
                PictureRow(slots: store.newSlicePictures,
                           selection: Binding(get: { slice.iconName.flatMap(KitSlot.init(rawValue:)) },
                                              set: { if let slot = $0 { store.send(.newSlicePicturePicked(slot.rawValue)) } }),
                           all: OurDayFeature.pictures, isShowingAll: slice.isPickingMore,
                           moreTitle: L10n.tr("picker.more"), columns: 4) {
                    store.send(.newSliceMoreTapped)
                }
                .zIndex(1)
                CrayonField(L10n.tr("day.new.name"), text: Binding(get: { slice.name },
                                                                   set: { store.send(.newSliceNameChanged($0)) }))
                if slice.isOnClock { timesRow }
            }
        } else if let title = store.selectedTitle, store.isSelectedSkipped {
            // Board G1g: the picture faded, the name, the times (soft) and "Bring back"; no scope tabs.
            VStack(alignment: .leading, spacing: sizing(Spacing.s)) {
                HStack(spacing: sizing(Spacing.s)) {
                    if let picture = store.selectedPicture { KitIcon(picture, size: sizing(64)).opacity(0.35) }
                    Text(title).crayonType(.head).foregroundStyle(CrayonColor.ink).lineLimit(1)
                }
                softTimes
                Button { store.send(.bringBackTapped) } label: {
                    Text(L10n.tr("day.bring_back")).crayonType(.body).bold().foregroundStyle(CrayonColor.link)
                }
                .buttonStyle(.plain)
            }
        } else if let title = store.selectedTitle {
            // Spec C6 "One card for everything on the clock": a day slice, an item or School.
            VStack(alignment: .leading, spacing: sizing(Spacing.s)) {
                HStack(spacing: sizing(Spacing.s)) {
                    if let picture = store.selectedPicture { KitIcon(picture, size: sizing(64)) }
                    Text(title).crayonType(.head).foregroundStyle(CrayonColor.ink).lineLimit(1)
                }
                // Spec "Edit scope": This day / All days under the title (not for a just-once item).
                if store.showsScopeTabs { scopeTabs }
                if store.timesAreEditable { timesRow } else { softTimes }
                if let message = store.message {
                    Text(message).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // "Skip this day" (This day) or "Remove" (All days, a just-once item), under the times.
                if let action = store.sliceActionTitle {
                    Button { store.send(.sliceActionTapped) } label: {
                        Text(action).crayonType(.body).bold().foregroundStyle(CrayonColor.lateText)
                    }
                    .buttonStyle(.plain)
                }
                if let details = store.detailsTitle {
                    Button { store.send(.detailsTapped) } label: {
                        GlyphText(details, glyph: .chevronRight, type: .body, color: CrayonColor.link)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// "5:00 pm → 6:30 pm" (soft), for a skipped slice or one whose times follow another event; the
    /// arrow is a part, the font has none.
    private var softTimes: some View {
        HStack(spacing: sizing(Spacing.xs)) {
            Text(store.startLabel ?? "").crayonType(.body).foregroundStyle(CrayonColor.softText)
            MarkerIcon(.arrowRight, size: sizing(28), color: CrayonColor.softText)
            Text(store.endLabel ?? "").crayonType(.body).foregroundStyle(CrayonColor.softText)
        }
    }

    /// Layout v42 fill rule: alone on their row, the two tabs share the slice card's width (2 × 206, gap 12).
    private var scopeTabs: some View {
        CrayonTabs(selection: Binding(get: { store.shownScope }, set: { store.send(.scopeTapped($0)) }),
                   items: [(EditScope.thisDay, L10n.tr("day.scope.this"), nil),
                           (.allDays, L10n.tr("day.scope.all"), nil)], fills: true, spacing: Spacing.sm)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Small cards: 24 × s inside.
    private var sliceCardInset: CGFloat { sizing.smallCardInset }

    /// Layout v43: one times row "[start] → [end]", two fields 176 × 80 and a 40 arrow, gap 16, all
    /// × s: it fits the 424 inside of the card on every screen, since everything scales together.
    private var timesRow: some View {
        HStack(spacing: sizing.pairGap) {
            startField
            MarkerIcon(.arrowRight, size: sizing.joiner, color: CrayonColor.softText)
            endField
        }
        .fixedSize()
    }

    private var startField: some View {
        TimeField(label: store.startLabel ?? "",
                  time: Binding(get: { store.startDate }, set: { store.send(.startPicked($0)) }),
                  width: sizing.timeFieldWidth)
    }

    private var endField: some View {
        TimeField(label: store.endLabel ?? "",
                  time: Binding(get: { store.endDate }, set: { store.send(.endPicked($0)) }),
                  width: sizing.timeFieldWidth)
    }
}
