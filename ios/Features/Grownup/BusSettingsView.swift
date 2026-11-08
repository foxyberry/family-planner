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
        } content: { grid in
            HStack(alignment: .top, spacing: grid.screenGutter) {
                PaperCard(seed: 51) { plan.padding(Spacing.m) }
                    .frame(width: grid.span(8))
                PaperCard(seed: 53) { keyCard.padding(Spacing.m) }
                    .frame(maxWidth: .infinity)
            }
        } primaryAction: { grid in
            InkButton(L10n.tr("c2.done")) { store.send(.doneTapped) }
                .frame(width: grid.span(4))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .task { await store.send(.task).finish() }
    }

    private var plan: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            Text(L10n.tr("c2.plan")).crayonType(.head).foregroundStyle(CrayonColor.ink)
            Text(L10n.tr("c2.for", store.kidName)).crayonType(.caption).foregroundStyle(CrayonColor.softText)
            ListRow(leading: L10n.tr("c2.stop")) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    CrayonField(L10n.tr("c2.stop.hint"),
                                text: Binding(get: { store.stop }, set: { store.send(.stopChanged($0)) }))
                        .keyboardType(.numberPad)
                        .frame(width: 240)
                    Text(store.stopCaption).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                }
            }
            ListRow(leading: L10n.tr("c2.buses")) {
                if store.servicesAtStop.isEmpty {
                    Text(L10n.tr("c2.buses.none")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                } else {
                    HStack(spacing: Spacing.s) {
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

    private var keyCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(L10n.tr("c2.key")).crayonType(.head).foregroundStyle(CrayonColor.ink)
            Text(store.keyCaption).crayonType(.caption).foregroundStyle(CrayonColor.softText)
            if let draft = store.keyDraft {
                CrayonField(L10n.tr("c2.key.field"),
                            text: Binding(get: { draft }, set: { store.send(.keyDraftChanged($0)) }), isSecure: true)
                InkButton(L10n.tr("c2.key.save")) { store.send(.keySaveTapped) }
            } else {
                // The key is built in; grown-ups only change it (spec "Bus settings").
                Button { store.send(.keyRowTapped) } label: {
                    Text(L10n.tr("c2.key.change")).crayonType(.body).foregroundStyle(CrayonColor.link)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
