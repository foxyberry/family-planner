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

    /// Board C2's rows: Stop (80 field and its caption), Buses (pills 180 × 72), then the steppers
    /// on a 104 pitch.
    private func plan(_ layout: GrownupLayout) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ListRow(leading: L10n.tr("c2.stop"), labelHeight: 80) {
                StopSearchField(store: store.scope(state: \.search, action: \.search), visibleRows: 8,
                                listWidth: layout.controlWidth)
            }
            .zIndex(1)
            ListRow(leading: L10n.tr("c2.buses"), labelHeight: PillToggle.size.height) {
                if store.search.servicesAtStop.isEmpty {
                    Text(L10n.tr("c2.buses.none")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                        .frame(height: PillToggle.size.height)
                } else {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        PillToggleGrid(controlWidth: layout.controlWidth) {
                            ForEach(store.search.servicesAtStop, id: \.self) { service in
                                PillToggle(service, isOn: store.services.first == service,
                                           tag: store.state.tag(for: service)) {
                                    store.send(.serviceTapped(service))
                                }
                            }
                        }
                    }
                }
            }
            stepper(L10n.tr("c2.walk"), text: store.walkText, caption: L10n.tr("c2.walk.caption"), step: 1,
                    value: store.walk) { store.send(.walkChanged($0)) }
            stepper(L10n.tr("c2.ride"), text: store.rideText, caption: store.rideCaption, step: 1,
                    value: store.ride) { store.send(.rideChanged($0)) }
            if store.second != nil {
                stepper(L10n.tr("c2.ride_second"), text: store.secondRideText, caption: store.secondRideCaption, step: 1,
                        value: store.secondRide) { store.send(.secondRideChanged($0)) }
            }
            stepper(L10n.tr("c2.grace"), text: store.graceText, caption: L10n.tr("c2.grace.caption"), step: 5,
                    value: store.lateGrace) { store.send(.graceChanged($0)) }
            if store.showsChangeLink { changeLink }
        }
    }

    /// Board C2 (y 900): "+ 2nd choice changes buses…" → C2c; a picked change reads "2nd choice · 34 › 33".
    private var changeLink: some View {
        let link = store.changeLink
        return ListRow(leading: "", minHeight: 72) { Button { store.send(.changeLinkTapped) } label: {
            HStack(spacing: Spacing.s) {
                if link.then == nil { MarkerIcon(.plus, size: 28, color: CrayonColor.ink) }
                Text(link.first).crayonType(.body, bold: true).foregroundStyle(CrayonColor.link)
                if let then = link.then {
                    MarkerIcon(.arrowRight, size: 28, color: CrayonColor.link)
                    Text(then).crayonType(.body, bold: true).foregroundStyle(CrayonColor.link)
                }
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

    /// − 72, the value, + 72, then what the number means (board C2).
    private func stepper(_ label: String, text: String, caption: String, step: Int, value: Int,
                         change: @escaping (Int) -> Void) -> some View {
        ListRow(leading: label, minHeight: 72) {
            HStack(spacing: Spacing.m) {
                RoundButton(glyph: .minus, accessibilityLabel: label) { change(value - step) }.size(72)
                Text(text).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink).frame(width: 112)
                RoundButton(glyph: .plus, accessibilityLabel: label) { change(value + step) }.size(72)
                Text(caption).crayonType(.body).foregroundStyle(CrayonColor.softText).lineLimit(1)
            }
        }
    }
}
