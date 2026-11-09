import ComposableArchitecture
import CrayonKit
import DesignSystem
import Domain
import KitArt
import Strings
import SwiftUI

/// C6 · Our day (board C6): drag the times of a kid's day on the clock.
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
                        .accessibilityHint(L10n.tr("day.hint"))
                    sideColumn(layout)
                        .frame(width: layout.side.width, height: layout.action.minY - Spacing.sm * layout.sizing.s
                               - layout.side.minY, alignment: .topLeading)
                }
            } primaryAction: { layout in
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    InkButton(L10n.tr("day.save")) { store.send(.saveTapped) }
                        .frame(width: layout.side.width)
                    if let error = store.saveError {
                        Text(error).crayonType(.caption).foregroundStyle(CrayonColor.lateText)
                    }
                }
            }
            if store.isConfirmingLeave {
                CrayonColor.marker.opacity(0.3).ignoresSafeArea()
                ConfirmCard(title: L10n.tr("day.leave.title"), message: nil, cancel: L10n.tr("day.leave.keep"),
                            confirm: L10n.tr("day.leave.leave"), isDestructive: true,
                            onCancel: { store.send(.leaveCancelled) }, onConfirm: { store.send(.leaveConfirmed) })
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: store.haptics.steps)
        .sensoryFeedback(.impact(weight: .medium), trigger: store.haptics.hours)
        .sensoryFeedback(.impact(weight: .heavy), trigger: store.haptics.bumps)
        .task { await store.send(.task).finish() }
    }

    private var header: some View {
        // Board C6: the kid tabs after the title; Undo on the right (1130–1312) instead of the caption.
        GrownupHeader(title: L10n.tr("day.title"), onBack: { store.send(.backTapped) }) {
            CrayonTabs(selection: Binding(get: { store.kid }, set: { store.send(.kidTabTapped($0)) }),
                       items: store.kids.map { ($0.id, $0.name, KidFace.Badge(face: $0.face, colorIndex: $0.colorIndex)) })
        } trailing: {
            Button { store.send(.undoTapped) } label: {
                Text(L10n.tr("day.undo")).crayonType(.body).foregroundStyle(CrayonColor.ink)
                    .frame(width: 182, height: 72)
                    .crayonBackground(.capsule, fill: CrayonStyle.paper, seed: 71)
            }
            .buttonStyle(.plain)
            .opacity(store.edit.isChanged ? 1 : 0.4)
            .disabled(!store.edit.isChanged)
        }
    }

    /// Board C6 (layout v6): the tabs and the slice card from the top; "Changes start tomorrow." just
    /// above the Save button and the hint above that, placed from the button up. When the hint would
    /// come within 8 of the card (short iPads) it is left out and stays the clock's VoiceOver hint.
    private func sideColumn(_ layout: GrownupLayout) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            CrayonTabs(selection: Binding(get: { store.dayType }, set: { store.send(.dayTypeTapped($0)) }),
                       items: [(DayType.weekday, L10n.tr("day.type.weekday"), nil),
                               (.saturday, L10n.tr("day.type.saturday"), nil),
                               (.sunday, L10n.tr("day.type.sunday"), nil)], compact: true)
                .fixedSize(horizontal: false, vertical: true)
            if store.showsHolidayNote {
                Text(L10n.tr("day.sun_holidays")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
            }
            // Board C6: the slice card is a fixed 382 × 440 box (a new slice's form may grow it); the
            // bottom stack hangs from the Save button.
            PaperCard(seed: 61) { card.frame(maxWidth: .infinity, alignment: .leading) }
                .frame(minHeight: 440 * layout.sizing.s, alignment: .top)
            Spacer(minLength: Spacing.xs)
            ViewThatFits(in: .vertical) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(L10n.tr("day.hint")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                        .fixedSize(horizontal: false, vertical: true)
                    tomorrow
                }
                tomorrow
            }
            // Board C6: "Changes start tomorrow." on baseline 850, so its descenders stay above the
            // paper behind the Save button (the line box is the type's own height, spec "Line height
            // is total").
            .padding(.bottom, Spacing.xs)
        }
    }

    private var tomorrow: some View {
        Text(L10n.tr("day.tomorrow")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
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
