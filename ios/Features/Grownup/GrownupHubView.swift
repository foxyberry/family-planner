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
                    // C1 / E6: the About values start on 280. The card stays 176–968 and only its rows
                    // scroll (spec C1); the header and tabs stay pinned.
                    PaperCard(seed: 21) {
                        ScrollView(.vertical) { aboutCard.frame(maxWidth: .infinity, alignment: .leading) }
                            .scrollIndicators(.hidden)
                    }
                    .environment(\.formLabelWidth, layout.valueLeft - layout.labelLeft)
                    .frame(width: layout.form.width, height: layout.form.height)
                    sideColumn
                        .frame(width: layout.side.width, alignment: .topLeading)
                }
            }
        } primaryAction: { _ in
            HStack(spacing: Spacing.m) {
                Button(L10n.tr("hub.data_sources")) { store.send(.dataSourcesTapped) }
                    .crayonType(.caption)
                    .foregroundStyle(CrayonColor.link)
                #if DEBUG
                    Button("Design gallery") { store.send(.galleryButtonTapped) } // copy-ok: debug builds only
                        .crayonType(.caption)
                        .foregroundStyle(CrayonColor.link)
                #endif
            }
        }
        .task { await store.send(.task).finish() }
    }

    private var header: some View {
        GrownupHeader(title: L10n.tr("hub.title"), onBack: { store.send(.backTapped) }) {
            if let kids = store.snapshot?.kids, let selected = store.selectedKid {
                // Boards C1/E6: tabs 200 × 72, gap 12.
                CrayonTabs(selection: Binding(get: { selected }, set: { store.send(.kidTabTapped($0)) }),
                           items: kids.map { ($0.id, $0.name, KidFace.Badge(face: $0.face, colorIndex: $0.colorIndex)) },
                           itemSize: CGSize(width: 200, height: 72), spacing: Spacing.sm)
            }
        }
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ForEach(store.sections, id: \.title) { section($0) }
        }
    }

    /// Board C1: a heading, then rows 60 tall with no gap between them.
    private func section(_ section: HubSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(section.title).crayonType(.head).foregroundStyle(CrayonColor.ink)
            ForEach(Array(section.rows.enumerated()), id: \.offset) { _, row in
                switch row {
                case let .text(row):
                    ListRow(leading: row.key, minHeight: 60) { value(row) }
                case let .link(row, link):
                    Button { store.send(Self.action(for: link)) } label: {
                        ListRow(leading: row.key, minHeight: 60) {
                            HStack {
                                value(row)
                                Spacer()
                                MarkerIcon(.chevronRight, size: 28, color: CrayonColor.softText)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                case let .schoolDays(key, days):
                    ListRow(leading: key, minHeight: 72) {
                        // Boards C1/E6: read-only chips 56 on a 64 pitch.
                        HStack(spacing: Spacing.xs) {
                            ForEach(Weekday.allCases.sorted(), id: \.self) { day in
                                DayChip(DayText.initial(day), isOn: .constant(days.contains(day)), size: 56)
                                    .allowsHitTesting(false)
                            }
                        }
                    }
                }
            }
        }
    }

    /// A row's value: its words, each piece after its picture (board C1: the sun before "Up", the
    /// moon before "Bed", the school picture 48 before the school's name).
    private func value(_ row: HubRow) -> some View {
        HStack(spacing: Spacing.xs) {
            ForEach(Array(row.parts.enumerated()), id: \.offset) { _, part in
                if let picture = part.picture {
                    KitIcon(KitSlot(iconName: picture), size: picture == "actSchool" ? 48 : 40) // copy-ok: a KitSlot name
                }
                Text(part.text).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var sideColumn: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(store.weeklyHeading).crayonType(.head)
            itemList(store.weeklyRows) { store.send(.weeklyItemTapped($0)) }
            addLink(L10n.tr("hub.add_weekly")) { store.send(.addWeeklyTapped) }
            Text(L10n.tr("hub.once")).crayonType(.head).padding(.top, Spacing.s)
            itemList(store.onceRows) { store.send(.onceItemTapped($0)) }
            addLink(L10n.tr("hub.add_once")) { store.send(.addOnceTapped) }
            if let more = store.moreRow {
                // Board C1: "More" in the side column; a row with the sun, its title over the count.
                Text(L10n.tr("hub.more")).crayonType(.head).padding(.top, Spacing.s)
                Button { store.send(.missionsRowTapped) } label: {
                    HStack(spacing: Spacing.s) {
                        KitIcon(KitSlot(iconName: more.picture), size: 56)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(more.title).crayonType(.body).lineLimit(1)
                            Text(more.caption).crayonType(.caption).foregroundStyle(CrayonColor.softText).lineLimit(1)
                        }
                        .layoutPriority(1)
                        Spacer(minLength: 0)
                        MarkerIcon(.chevronRight, size: 28, color: CrayonColor.softText)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
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
                // Board C1: a 56 plus circle.
                RoundButton(glyph: .plus, accessibilityLabel: title, action: action).size(56).allowsHitTesting(false)
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
