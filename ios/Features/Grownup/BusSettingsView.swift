import ComposableArchitecture
import CrayonKit
import DesignSystem
import Strings
import SwiftUI

/// C2 · Our buses (board C2, first cut): plan A for one kid.
public struct BusSettingsView: View {
    @Bindable var store: StoreOf<BusSettingsFeature>

    public init(store: StoreOf<BusSettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        // Spec "Scrolling": the card stays put and its rows scroll inside it; the side scrolls on its own.
        GrownupScreen(scrolls: false) {
            GrownupHeader(title: store.title, onBack: { store.send(.doneTapped) })
        } content: { layout in
            HStack(alignment: .top, spacing: layout.gap) {
                // Board C2: the card runs 148–968, exactly its inner width, so a long row of buses can
                // never widen it; a stop with many buses scrolls its rows inside the card.
                PaperCard(seed: 51) {
                    ScrollColumn {
                        plan(layout).frame(width: layout.editorRowsWidth, alignment: .leading)
                    }
                }
                .frame(width: layout.form.width, height: layout.form.height, alignment: .top)
                ScrollColumn { side }
                    .frame(width: layout.side.width, height: layout.action.minY - layout.side.minY - Spacing.s,
                           alignment: .topLeading)
            }
        } primaryAction: { layout in
            InkButton(L10n.tr("c2.done")) { store.send(.doneTapped) }
                .frame(width: layout.side.width)
        }
        .resultVeil(isOpen: store.search.isListOpen) { store.send(.search(.listClosed)) }
        .task { await store.send(.task).finish() }
    }

    /// Board C2 (layout v58): Stop (80 field and its caption), Buses (pills 180 × 72), the steppers,
    /// then the link; rows 24 apart between drawn edges (spec "Layout balance").
    private func plan(_ layout: GrownupLayout) -> some View {
        VStack(alignment: .leading, spacing: layout.sizing.formRowGap) {
            ListRow(leading: L10n.tr("c2.stop"), labelHeight: layout.sizing.fieldHeight) {
                StopSearchField(store: store.scope(state: \.search, action: \.search), visibleRows: 8,
                                listWidth: layout.controlWidth)
            }
            .captionedRow()
            .zIndex(1)
            ListRow(leading: L10n.tr("c2.buses"), minHeight: layout.sizing.tabHeight(), labelHeight: layout.sizing.tabHeight()) {
                if store.search.servicesAtStop.isEmpty {
                    Text(L10n.tr("c2.buses.none")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                        .frame(height: layout.sizing.tabHeight())
                } else {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        PillToggleGrid(controlWidth: layout.controlWidth) {
                            ForEach(store.search.servicesAtStop, id: \.self) { service in
                                PillToggle(service, isOn: store.services.contains(service)) {
                                    store.send(.serviceTapped(service))
                                }
                            }
                            // Spec "Several buses": the bus that changes is one more pill; a tap reopens C2c.
                            if let change = store.change {
                                PillToggle(change.firstBus, isOn: true, then: change.thenBus) {
                                    store.send(.changeLinkTapped)
                                }
                            }
                        }
                    }
                }
            }
            .drawnRow()
            stepper(L10n.tr("c2.walk"), text: store.walkText, caption: L10n.tr("c2.walk.caption"), step: 1,
                    value: store.walk, sizing: layout.sizing) { store.send(.walkChanged($0)) }
            ForEach(store.rideRows) { row in
                stepper(row.label, text: row.text, caption: row.caption, step: 1,
                        value: row.minutes, spoken: row.spoken, sizing: layout.sizing) {
                    store.send(.rideChanged(service: row.service, minutes: $0))
                }
            }
            stepper(L10n.tr("c2.grace"), text: store.graceText, caption: L10n.tr("c2.grace.caption"), step: 5,
                    value: store.lateGrace, sizing: layout.sizing) { store.send(.graceChanged($0)) }
            if store.showsChangeLink { changeLink }
        }
    }

    /// Board C2 (v57, y 742): "+ A bus that changes…" → C2c.
    private var changeLink: some View {
        ListRow(leading: "", minHeight: 72) { Button { store.send(.changeLinkTapped) } label: {
            HStack(spacing: Spacing.s) {
                MarkerIcon(.plus, size: 28, color: CrayonColor.ink)
                Text(store.changeLink).crayonType(.body, bold: true).foregroundStyle(CrayonColor.link)
            }
            .frame(minHeight: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain) }
    }

    /// Board C2's side column (layout v38, plain screens): whose route it is, nothing more.
    private var side: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(store.sideTitle).crayonType(.head)
        }
        .foregroundStyle(CrayonColor.ink)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// A minutes row (board C2): the shared stepper, laid out by its drawn box.
    private func stepper(_ label: String, text: String, caption: String, step: Int, value: Int,
                         spoken: String? = nil, sizing: Sizing, change: @escaping (Int) -> Void) -> some View {
        ListRow(leading: label, minHeight: MinutesStepper.rowHeight(sizing)) {
            MinutesStepper(value: text, caption: caption, spoken: spoken ?? label,
                           minus: { change(value - step) }, plus: { change(value + step) })
        }
        .drawnRow()
    }
}
