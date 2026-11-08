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
    @Dependency(\.calendar) private var calendar

    public init(store: StoreOf<GrownupHubFeature>) {
        self.store = store
    }

    public var body: some View {
        GrownupScreen {
            header
        } content: { grid in
            if let kid = store.kid, let snapshot = store.snapshot {
                HStack(alignment: .top, spacing: GridMetrics.gutter) {
                    PaperCard(seed: 21) { aboutCard(kid, snapshot) }
                        .frame(width: grid.span(8))
                    sideColumn(kid, snapshot)
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

    private func aboutCard(_ kid: Kid, _ snapshot: ScheduleSnapshot) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            section("About", HubModel.aboutRows(kid: kid, routines: snapshot.routines))
            if let school = kid.school {
                section("School", HubModel.schoolRows(kid: kid)) {
                    ListRow(leading: "Days") {
                        HStack(spacing: Spacing.xs) {
                            ForEach(Weekday.allCases.sorted(), id: \.self) { day in
                                DayChip(String(DayText.shortName(day).prefix(1)), isOn: .constant(school.days.contains(day)))
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                }
            } else {
                section("Nursery", [HubRow(key: "Nursery", value: "Not yet")])
                section("Morning", [HubRow(key: "Taps", value: "A grown-up taps for now")])
            }
        }
        .padding(Spacing.m)
    }

    private func section(_ title: String, _ rows: [HubRow], @ViewBuilder extra: () -> some View = { EmptyView() })
        -> some View {
        let extra = extra()
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title).crayonType(.head).foregroundStyle(CrayonColor.ink).padding(.top, Spacing.s)
            ForEach(rows, id: \.key) { row in
                ListRow(leading: row.key) {
                    Text(row.value).crayonType(.body).foregroundStyle(CrayonColor.ink)
                }
                if row.key == "School" { extra }
            }
        }
    }

    private func sideColumn(_ kid: Kid, _ snapshot: ScheduleSnapshot) -> some View {
        let weekly = HubModel.weeklyRows(kid: kid, items: snapshot.items)
        let once = store.today.map {
            HubModel.onceRows(kid: kid, items: snapshot.items, routines: snapshot.routines, today: $0,
                              nowMinute: store.nowMinute, calendar: calendar)
        } ?? []
        return VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(kid.school == nil ? "Every week" : "After school").crayonType(.head)
            itemList(weekly) { store.send(.weeklyItemTapped($0)) }
            addLink("Add every week") { store.send(.addWeeklyTapped) }
            Text("Just once").crayonType(.head).padding(.top, Spacing.s)
            itemList(once) { store.send(.onceItemTapped($0)) }
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
                    KitIcon(KitSlot(rawValue: row.iconName) ?? .actPlay, size: 56)
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
