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
            HStack(alignment: .top, spacing: layout.gap) {
                // Board C2: the card runs 176–968 at least, exactly its inner width, so a long row of
                // buses can never widen it. A stop with many buses makes it taller and the screen
                // scrolls (iPad review: a fixed height squeezed the rows on top of each other).
                PaperCard(seed: 51) {
                    plan.frame(width: layout.form.width - 2 * layout.formInset, alignment: .leading)
                        .frame(minHeight: layout.form.height - 2 * layout.formInset, alignment: .top)
                }
                .frame(width: layout.form.width, alignment: .top)
                side.frame(width: layout.side.width, alignment: .topLeading)
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
    private var plan: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ListRow(leading: L10n.tr("c2.stop"), labelHeight: 80) {
                StopSearchField(store: store.scope(state: \.search, action: \.search), visibleRows: 8)
            }
            .zIndex(1)
            ListRow(leading: L10n.tr("c2.buses"), labelHeight: PillToggle.size.height) {
                if store.search.servicesAtStop.isEmpty {
                    Text(L10n.tr("c2.buses.none")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                        .frame(height: PillToggle.size.height)
                } else {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        LazyVGrid(columns: PillToggle.columns, alignment: .leading, spacing: Spacing.sm) {
                            ForEach(store.search.servicesAtStop, id: \.self) { service in
                                PillToggle(service, isOn: store.services.contains(service)) {
                                    store.send(.serviceTapped(service))
                                }
                            }
                        }
                        Text(L10n.tr("s3.buses.caption")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    }
                }
            }
            stepper(L10n.tr("c2.walk"), text: store.walkText, caption: L10n.tr("c2.walk.caption"), step: 1,
                    value: store.walk) { store.send(.walkChanged($0)) }
            stepper(L10n.tr("c2.ride"), text: store.rideText, caption: store.rideCaption, step: 1,
                    value: store.ride) { store.send(.rideChanged($0)) }
            stepper(L10n.tr("c2.grace"), text: store.graceText, caption: L10n.tr("c2.grace.caption"), step: 5,
                    value: store.lateGrace) { store.send(.graceChanged($0)) }
        }
    }

    /// Board C2's side column: whose route it is, how "Leave in" works, then the morning map.
    private var side: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(store.sideTitle).crayonType(.head)
            Text(L10n.tr("s3.side.leave_in")).crayonType(.body)
            Text(L10n.tr("c2.side.arrive")).crayonType(.caption).foregroundStyle(CrayonColor.softText)
            Text(L10n.tr("c2.side.map")).crayonType(.head).padding(.top, Spacing.m)
            Text(store.mapCaption).crayonType(.caption).foregroundStyle(CrayonColor.softText)
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
