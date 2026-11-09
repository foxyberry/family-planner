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
        GrownupScreen {
            GrownupHeader(title: store.title, onBack: { store.send(.doneTapped) })
        } content: { layout in
            // Exactly the card's inner width, so a long row of buses can never widen the card.
            PaperCard(seed: 51) { plan.frame(width: layout.form.width - 2 * layout.formInset, alignment: .leading) }
                .frame(width: layout.form.width)
        } primaryAction: { layout in
            InkButton(L10n.tr("c2.done")) { store.send(.doneTapped) }
                .frame(width: layout.side.width)
        }
        .task { await store.send(.task).finish() }
    }

    private var plan: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(L10n.tr("c2.plan")).crayonType(.head).foregroundStyle(CrayonColor.ink)
            Text(L10n.tr("c2.for", store.kidName)).crayonType(.caption).foregroundStyle(CrayonColor.softText)
            // Board C2 (v9): the stop field (400 × 80 on 232), its caption 8 below, and the list of
            // matches as a card 40 below the field, over the rows under it.
            ListRow(leading: L10n.tr("c2.stop")) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    CrayonField(L10n.tr("c2.stop.placeholder"),
                                text: Binding(get: { store.stopText }, set: { store.send(.stopChanged($0)) }))
                        .frame(width: 400)
                        .overlay(alignment: .topLeading) {
                            if !store.stopMatches.isEmpty { matches.offset(y: 80 + Spacing.l) }
                        }
                    HStack(spacing: Spacing.xs) {
                        if store.pickedStop != nil { CheckMark(isDone: true, size: 32) }
                        Text(store.stopCaption).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    }
                }
            }
            .zIndex(1)
            ListRow(leading: L10n.tr("c2.buses")) {
                if store.servicesAtStop.isEmpty {
                    Text(L10n.tr("c2.buses.none")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                } else {
                    // As many rows as the buses need, never wider than the controls (232 … 842).
                    // Seven 72 chips 12 apart fill 576 of the 610 control width; an adaptive grid would centre.
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(72), spacing: Spacing.sm), count: 7),
                              alignment: .leading, spacing: Spacing.sm) {
                        ForEach(store.servicesAtStop, id: \.self) { service in
                            DayChip(service, isOn: Binding(get: { store.services.contains(service) },
                                                           set: { _ in store.send(.serviceTapped(service)) }))
                        }
                    }
                }
            }
            stepper(L10n.tr("c2.walk"), text: store.walkText, step: 1,
                    value: store.walk) { store.send(.walkChanged($0)) }
            stepper(L10n.tr("c2.ride"), text: store.rideText, step: 1,
                    value: store.ride) { store.send(.rideChanged($0)) }
            stepper(L10n.tr("c2.grace"), text: store.graceText, step: 5,
                    value: store.lateGrace) { store.send(.graceChanged($0)) }
        }
    }

    private func stepper(_ label: String, text: String, step: Int, value: Int,
                         change: @escaping (Int) -> Void) -> some View {
        ListRow(leading: label) {
            HStack(spacing: Spacing.m) {
                RoundButton(glyph: .minus, accessibilityLabel: label) { change(value - step) }
                Text(text).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink).frame(width: 112)
                RoundButton(glyph: .plus, accessibilityLabel: label) { change(value + step) }
            }
        }
    }

    /// Stops matching the typed name: a white card of 64-tall rows, the name over road and code.
    private var matches: some View {
        PaperCard(seed: 55) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(store.stopMatches.enumerated()), id: \.element.id) { index, stop in
                    if index > 0 { Rectangle().fill(CrayonColor.paper).frame(height: 2) }
                    Button { store.send(.stopPicked(stop)) } label: {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(stop.name).crayonType(.body, bold: true).foregroundStyle(CrayonColor.link).lineLimit(1)
                            Text(L10n.tr("c2.stop.match", stop.road, stop.code)).crayonType(.caption)
                                .foregroundStyle(CrayonColor.softText).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .environment(\.cardInset, Spacing.m)
        .frame(width: 400)
    }
}
