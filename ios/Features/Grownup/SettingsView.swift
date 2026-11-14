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
            Button(L10n.tr("hub.data_sources")) { store.send(.dataSourcesTapped) }
                .crayonType(.caption, bold: true)
                .foregroundStyle(CrayonColor.link)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .task { await store.send(.task).finish() }
    }

    private var header: some View {
        GrownupHeader(title: L10n.tr("settings.title"), onBack: { store.send(.backTapped) }) {
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

    private var kidCard: some View {
        VStack(alignment: .leading, spacing: Spacing.m) {
            ForEach(store.sections, id: \.title) { section in
                VStack(alignment: .leading, spacing: 0) {
                    Text(section.title).crayonType(.head).foregroundStyle(CrayonColor.ink)
                    ForEach(Array(section.rows.enumerated()), id: \.offset) { _, row in
                        if let link = row.link {
                            Button { store.send(link == .buses ? .busesRowTapped : .missionsRowTapped) } label: {
                                ListRow(leading: row.key, minHeight: 60) {
                                    HStack {
                                        value(row)
                                        Spacer()
                                        MarkerIcon(.chevronRight, size: 28, color: CrayonColor.softText)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        } else {
                            ListRow(leading: row.key, minHeight: 60) { value(row) }
                        }
                    }
                }
            }
        }
    }

    /// The Family tab: this iPad's switches (the same rows as S4).
    private var familyCard: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text(L10n.tr("settings.this_ipad")).crayonType(.head).foregroundStyle(CrayonColor.ink)
            ForEach(store.settingRows, id: \.setting) { row in
                SettingRow(title: row.title, caption: row.caption, captionIsWarning: row.isWarning, isOn: row.isOn,
                           action: { store.send(.settingTapped(row.setting)) }) {
                    switch row.picture {
                    case .lock: LockMark(size: 56)
                    case let .kit(name): KitIcon(KitSlot(iconName: name), size: 56)
                    }
                }
            }
        }
    }

    /// A row's value: its picture (40), then its words.
    private func value(_ row: SettingsRow) -> some View {
        HStack(spacing: Spacing.xs) {
            if let picture = row.picture { KitIcon(KitSlot(iconName: picture), size: 40) }
            Text(row.value).crayonType(.body).foregroundStyle(CrayonColor.ink).lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}
