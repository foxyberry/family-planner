import AppSettings
import ComposableArchitecture
import CrayonKit
import DesignSystem
import Domain
import KitArt
import Strings
import SwiftUI

/// Settings (board G6). The header and tabs stay put; the card's rows scroll.
public struct SettingsView: View {
    @Environment(\.sizing) private var sizing
    @Bindable var store: StoreOf<SettingsFeature>

    public init(store: StoreOf<SettingsFeature>) {
        self.store = store
    }

    public var body: some View {
        // Spec "Scrolling on G1 / G6": the card stays put and only its rows scroll.
        GrownupScreen(scrolls: false) {
            header
        } content: { layout in
            HStack(alignment: .top, spacing: layout.gap) {
                // Board G6: labels on 104, values on 280, "›" at 814; rows 60 tall.
                PaperCard(seed: 21) {
                    ScrollColumn {
                        Group { if store.tab == .family { familyCard } else { kidCard } }
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .environment(\.formLabelWidth, layout.valueLeft - layout.labelLeft)
                .frame(width: layout.form.width, height: layout.form.height)
                Color.clear.frame(width: layout.side.width, height: 1)
            }
        } primaryAction: { _ in
            VStack(alignment: .leading, spacing: sizing(Spacing.xxs)) {
                if let lists = store.listsLine {
                    Text(lists).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                }
                Button(L10n.tr("hub.data_sources")) { store.send(.dataSourcesTapped) }
                    .crayonType(.caption, bold: true)
                    .foregroundStyle(CrayonColor.link)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task { await store.send(.task).finish() }
    }

    private var header: some View {
        GrownupHeader(title: L10n.tr("settings.title"), caption: store.headerCaption,
                      onBack: { store.send(.backTapped) }) {
            if let tab = store.tab {
                // Board G6: a tab per kid, then "Family".
                CrayonTabs(selection: Binding(get: { tab }, set: { store.send(.tabTapped($0)) }),
                           items: store.tabs.map { tab, name, kid in
                               (tab, kid == nil ? L10n.tr("settings.family") : name,
                                kid.map { KidFace.Badge(face: $0.face, colorIndex: $0.colorIndex) })
                           },
                           spacing: Spacing.sm)
            }
        }
    }

    private static func action(for link: SettingsLink) -> SettingsFeature.Action {
        switch link {
        case .buses: .busesRowTapped
        case .missions: .missionsRowTapped
        case .school: .schoolRowTapped
        case .changeSchool: .changeSchoolRowTapped
        case .waitingHours: .waitingHoursRowTapped
        }
    }

    private var kidCard: some View {
        VStack(alignment: .leading, spacing: sizing(Spacing.m)) {
            ForEach(store.sections, id: \.title) { section in
                VStack(alignment: .leading, spacing: 0) {
                    Text(section.title).crayonType(.head).foregroundStyle(CrayonColor.ink)
                    ForEach(Array(section.rows.enumerated()), id: \.offset) { _, row in
                        if let link = row.link {
                            Button { store.send(Self.action(for: link)) } label: {
                                ListRow(leading: row.key, minHeight: sizing(60)) {
                                    HStack {
                                        value(row)
                                        Spacer()
                                        MarkerIcon(.chevronRight, size: sizing(28), color: CrayonColor.softText)
                                    }
                                }
                                // The whole row opens it, the gap before › too (a plain button only
                                // hits its drawn parts).
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        } else {
                            ListRow(leading: row.key, minHeight: sizing(60)) { value(row) }
                        }
                    }
                }
            }
        }
    }

    /// Board G6f: "This iPad" (the S4 switches), then "Children" and "+ Add a child".
    private var familyCard: some View {
        VStack(alignment: .leading, spacing: sizing(Spacing.s)) {
            switches
            Text(L10n.tr("settings.children")).crayonType(.head).foregroundStyle(CrayonColor.ink)
                .padding(.top, sizing(Spacing.m))
            ForEach(store.childRows, id: \.kid.id) { row in
                Button { store.send(.childTapped(row.kid.id)) } label: {
                    HStack(spacing: sizing(Spacing.s)) {
                        KidFace(KidFace.Badge(face: row.kid.face, colorIndex: row.kid.colorIndex),
                                size: sizing(KidFace.medium))
                        Text(row.kid.name).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink)
                        Text(row.detail).crayonType(.body).foregroundStyle(CrayonColor.softText).lineLimit(1)
                        Spacer(minLength: 0)
                        MarkerIcon(.chevronRight, size: sizing(28), color: CrayonColor.softText)
                    }
                    .frame(minHeight: sizing(72))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if store.canAddChild {
                Button { store.send(.addChildTapped) } label: {
                    HStack(spacing: sizing(Spacing.s)) {
                        MarkerIcon(.plus, size: sizing(28), color: CrayonColor.ink)
                            .frame(width: sizing(56), height: sizing(56))
                            .crayonBackground(.circle, fill: nil, seed: 1806)
                        Text(L10n.tr("settings.add_child")).crayonType(.body).foregroundStyle(CrayonColor.link)
                    }
                    .frame(minHeight: sizing(72))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var switches: some View {
        VStack(alignment: .leading, spacing: sizing(Spacing.s)) {
            Text(L10n.tr("settings.this_ipad")).crayonType(.head).foregroundStyle(CrayonColor.ink)
            ForEach(store.settingRows, id: \.setting) { row in
                SettingRow(title: row.title, caption: row.caption, captionIsWarning: row.isWarning, isOn: row.isOn,
                           action: { store.send(.settingTapped(row.setting)) }) {
                    switch row.picture {
                    case .lock: LockMark(size: sizing.settingRowPicture)
                    case let .kit(name): KitIcon(KitSlot(iconName: name), size: sizing.settingRowPicture)
                    }
                }
            }
        }
    }

    /// A row's value: its picture (40), then its words.
    private func value(_ row: SettingsRow) -> some View {
        HStack(spacing: sizing(Spacing.xs)) {
            if let picture = row.picture { KitIcon(KitSlot(iconName: picture), size: sizing(40)) }
            Text(row.value).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(1)
        }
    }
}
