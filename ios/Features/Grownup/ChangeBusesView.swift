import ComposableArchitecture
import CrayonKit
import DesignSystem
import Strings
import SwiftUI

/// C2c · 2nd choice · change buses (board C2c): From, First bus, Change at, Then, Ride 1, Walk, Ride 2.
public struct ChangeBusesView: View {
    @Bindable var store: StoreOf<ChangeBusesFeature>

    public init(store: StoreOf<ChangeBusesFeature>) {
        self.store = store
    }

    public var body: some View {
        GrownupScreen(scrolls: false) {
            GrownupHeader(title: store.title, onBack: { store.send(.backTapped) })
        } content: { layout in
            HStack(alignment: .top, spacing: layout.gap) {
                PaperCard(seed: 52) {
                    ScrollColumn {
                        rows(layout).frame(width: layout.form.width - 2 * layout.formInset, alignment: .leading)
                    }
                }
                .frame(width: layout.form.width, height: layout.form.height, alignment: .top)
                Color.clear.frame(width: layout.side.width, height: 1)
            }
        } primaryAction: { layout in
            InkButton(L10n.tr("c2c.save")) { store.send(.saveTapped) }
                .disabled(!store.canSave)
                .frame(width: layout.side.width)
        }
        .resultVeil(isOpen: store.search.isListOpen) { store.send(.search(.listClosed)) }
        .task { await store.send(.task).finish() }
    }

    private func rows(_ layout: GrownupLayout) -> some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ListRow(leading: L10n.tr("c2c.from"), minHeight: 72) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                    Text(store.fromName).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink)
                    Text(L10n.tr("c2c.our_stop")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                }
            }
            pills(L10n.tr("c2c.first_bus"), services: store.firstBuses, picked: store.firstBus) {
                store.send(.firstBusTapped($0))
            }
            ListRow(leading: L10n.tr("c2c.change_at"), labelHeight: 80) {
                StopSearchField(store: store.scope(state: \.search, action: \.search), visibleRows: 6,
                                listWidth: layout.controlWidth)
            }
            .zIndex(1)
            pills(L10n.tr("c2c.then"), services: store.thenBuses, picked: store.thenBus) {
                store.send(.thenBusTapped($0))
            }
            stepper(L10n.tr("c2c.ride1"), text: store.ride1Text, caption: store.ride1Caption, value: store.ride1) {
                store.send(.ride1Changed($0))
            }
            stepper(L10n.tr("c2c.walk"), text: store.walkText, caption: L10n.tr("c2c.walk.caption"), value: store.walk) {
                store.send(.walkChanged($0))
            }
            stepper(L10n.tr("c2c.ride2"), text: store.ride2Text, caption: store.ride2Caption, value: store.ride2) {
                store.send(.ride2Changed($0))
            }
        }
    }

    /// Bus pills (180 × 72), one picked; "No buses found" while the stop has none.
    private func pills(_ label: String, services: [String], picked: String?,
                       tap: @escaping (String) -> Void) -> some View {
        ListRow(leading: label, labelHeight: PillToggle.size.height) {
            if services.isEmpty {
                Text(L10n.tr("c2.buses.none")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    .frame(height: PillToggle.size.height)
            } else {
                LazyVGrid(columns: PillToggle.columns, alignment: .leading, spacing: Spacing.sm) {
                    ForEach(services, id: \.self) { service in
                        PillToggle(service, isOn: picked == service) { tap(service) }
                    }
                }
            }
        }
    }

    private func stepper(_ label: String, text: String, caption: String, value: Int,
                         change: @escaping (Int) -> Void) -> some View {
        ListRow(leading: label, minHeight: 72) {
            HStack(spacing: Spacing.m) {
                RoundButton(glyph: .minus, accessibilityLabel: label) { change(value - 1) }.size(72)
                Text(text).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink).frame(width: 112)
                RoundButton(glyph: .plus, accessibilityLabel: label) { change(value + 1) }.size(72)
                Text(caption).crayonType(.body).foregroundStyle(CrayonColor.softText).lineLimit(1)
            }
        }
    }
}
