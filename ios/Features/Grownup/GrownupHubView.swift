import ComposableArchitecture
import CrayonKit
import DesignSystem
import Domain
import KitArt
import ScheduleStore
import Strings
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
        } content: { layout in
            if store.kid != nil {
                HStack(alignment: .top, spacing: layout.gap) {
                    // C1 / E6: the About values start on 280.
                    PaperCard(seed: 21) { aboutCard }
                        .environment(\.formLabelWidth, layout.valueLeft - layout.labelLeft)
                        .frame(width: layout.form.width)
                    sideColumn
                        .frame(width: layout.side.width, alignment: .topLeading)
                }
            }
        } primaryAction: { _ in
            #if DEBUG
                Button("Design gallery") { store.send(.galleryButtonTapped) } // copy-ok: debug builds only
                    .crayonType(.caption)
                    .foregroundStyle(CrayonColor.link)
            #endif
        }
        .task { await store.send(.task).finish() }
    }

    private var header: some View {
        GrownupHeader(title: L10n.tr("hub.title"), onBack: { store.send(.backTapped) }) {
            if let kids = store.snapshot?.kids, let selected = store.selectedKid {
                CrayonTabs(selection: Binding(get: { selected }, set: { store.send(.kidTabTapped($0)) }),
                           items: kids.map { ($0.id, $0.name, KidFace.Badge(face: $0.face, colorIndex: $0.colorIndex)) })
            }
        }
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            ForEach(store.sections, id: \.title) { section($0) }
        }
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
                case let .link(row, link):
                    Button { store.send(Self.action(for: link)) } label: {
                        ListRow(leading: row.key) {
                            HStack {
                                Text(row.value).crayonType(.body).foregroundStyle(CrayonColor.ink)
                                Spacer()
                                MarkerIcon(.chevronRight, size: 28, color: CrayonColor.softText)
                            }
                        }
                    }
                    .buttonStyle(.plain)
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
            addLink(L10n.tr("hub.add_weekly")) { store.send(.addWeeklyTapped) }
            Text(L10n.tr("hub.once")).crayonType(.head).padding(.top, Spacing.s)
            itemList(store.onceRows) { store.send(.onceItemTapped($0)) }
            addLink(L10n.tr("hub.add_once")) { store.send(.addOnceTapped) }
        }
        .foregroundStyle(CrayonColor.ink)
    }

    @ViewBuilder
    private func itemList(_ rows: [HubItemRow], onTap: @escaping (ScheduleItem.ID) -> Void) -> some View {
        if rows.isEmpty {
            Text(L10n.tr("hub.empty")).crayonType(.body).foregroundStyle(CrayonColor.softText)
        }
        ForEach(rows) { row in
            Button { onTap(row.id) } label: {
                // Picture, then the title over its days and times: the whole row is the button, so it
                // carries no chevron (the time needs that room in 382).
                HStack(spacing: Spacing.s) {
                    KitIcon(KitSlot(iconName: row.iconName), size: 56)
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(row.title).crayonType(.body).lineLimit(1)
                        // One line when it fits; otherwise the days or date over the time, never cut.
                        ViewThatFits(in: .horizontal) {
                            Text(row.detail).lineLimit(1)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(row.when).lineLimit(1)
                                Text(row.time).lineLimit(1)
                            }
                        }
                        .crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func addLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                RoundButton(glyph: .plus, accessibilityLabel: title, action: action).allowsHitTesting(false)
                Text(title).crayonType(.body).foregroundStyle(CrayonColor.link)
            }
        }
        .buttonStyle(.plain)
    }

    private static func action(for link: HubLink) -> GrownupHubFeature.Action {
        switch link {
        case .day: .dayRowTapped
        case .missions: .missionsRowTapped
        case .buses: .busesRowTapped
        }
    }
}
