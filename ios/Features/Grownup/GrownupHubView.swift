import ComposableArchitecture
import CrayonKit
import DesignSystem
import Domain
import KitArt
import ScheduleStore
import SwiftUI

/// Our kids (boards C1, E6). The header and tabs stay put; the cards scroll.
public struct GrownupHubView: View {
    @Bindable var store: StoreOf<GrownupHubFeature>

    public init(store: StoreOf<GrownupHubFeature>) {
        self.store = store
    }

    public var body: some View {
        GrownupScreen {
            header
        } content: { grid in
            if store.kid != nil {
                HStack(alignment: .top, spacing: GridMetrics.gutter) {
                    PaperCard(seed: 21) { aboutCard }
                        .frame(width: grid.span(8))
                    sideColumn
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        } primaryAction: { _ in
            #if DEBUG
                Button("Design gallery") { store.send(.galleryButtonTapped) }
                    .crayonType(.caption)
                    .foregroundStyle(CrayonColor.link)
            #endif
        }
        .task { await store.send(.task).finish() }
    }

    private var header: some View {
        GrownupHeader(title: "Our kids", onBack: { store.send(.backTapped) }) {
            if let kids = store.snapshot?.kids, let selected = store.selectedKid {
                CrayonTabs(selection: Binding(get: { selected }, set: { store.send(.kidTabTapped($0)) }),
                           items: kids.map { ($0.id, $0.name, CrayonColor.kid($0.colorIndex)) })
            }
        }
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            ForEach(store.sections, id: \.title) { section($0) }
        }
        .padding(Spacing.m)
    }

    private func section(_ section: HubSection) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(section.title).crayonType(.head).foregroundStyle(CrayonColor.ink).padding(.top, Spacing.s)
            ForEach(Array(section.rows.enumerated()), id: \.offset) { _, row in
                switch row {
                case let .text(row):
                    ListRow(leading: row.key) {
                        Text(row.value).crayonType(.body).foregroundStyle(CrayonColor.ink)
                    }
                case let .schoolDays(key, days):
                    ListRow(leading: key) {
                        HStack(spacing: Spacing.xs) {
                            ForEach(Weekday.allCases.sorted(), id: \.self) { day in
                                DayChip(DayText.initial(day), isOn: .constant(days.contains(day)))
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                }
            }
        }
    }

    private var sideColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(store.weeklyHeading).crayonType(.head)
            itemList(store.weeklyRows) { store.send(.weeklyItemTapped($0)) }
            addLink("Add every week") { store.send(.addWeeklyTapped) }
            Text("Just once").crayonType(.head).padding(.top, Spacing.s)
            itemList(store.onceRows) { store.send(.onceItemTapped($0)) }
            addLink("Add once") { store.send(.addOnceTapped) }
            Text("Everything here feeds the clock, the morning bus and the diary.")
                .crayonType(.caption).foregroundStyle(CrayonColor.softText).padding(.top, Spacing.s)
        }
        .foregroundStyle(CrayonColor.ink)
    }

    @ViewBuilder
    private func itemList(_ rows: [HubItemRow], onTap: @escaping (ScheduleItem.ID) -> Void) -> some View {
        if rows.isEmpty {
            Text("Nothing yet").crayonType(.body).foregroundStyle(CrayonColor.softText)
        }
        ForEach(rows) { row in
            Button { onTap(row.id) } label: {
                HStack(spacing: Spacing.s) {
                    KitIcon(KitSlot(iconName: row.iconName), size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title).crayonType(.body)
                        Text(row.detail).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(CrayonColor.softText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func addLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                RoundButton(text: "+", accessibilityLabel: title, action: action).allowsHitTesting(false)
                Text(title).crayonType(.body).foregroundStyle(CrayonColor.link)
            }
        }
        .buttonStyle(.plain)
    }
}
