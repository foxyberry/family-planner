import ComposableArchitecture
import CrayonKit
import DesignSystem
import Domain
import KitArt
import Strings
import SwiftUI

/// A2-MVP · Morning missions (board A2-MVP): header, the way strip, the kid list and the chosen
/// kid's missions, "All done!". Kids never scroll here: more missions turn a page ("+n").
public struct MissionsView: View {
    let store: StoreOf<MissionsFeature>
    @State private var ticks = 0
    @Environment(\.sizing) private var sizing

    public init(store: StoreOf<MissionsFeature>) {
        self.store = store
    }

    public var body: some View {
        // Board A2-MVP fixed regions (spec "Fixed regions"): header 48–128, strip 176–516, kids and
        // missions 536–968. No region moves or resizes with its content.
        KidFullScreen {
            ZStack(alignment: .topLeading) {
                header
                    .frame(width: sizing.stretchWidth, height: 80 * sizing.s)
                    .offset(x: sizing.margin, y: sizing.y(48))
                strip
                    .frame(width: sizing.stretchWidth, height: 340 * sizing.s)
                    .offset(x: sizing.margin, y: sizing.y(176))
                missionsArea
                    .frame(width: sizing.stretchWidth, height: (968 - 536) * sizing.s, alignment: .topLeading)
                    .offset(x: sizing.margin, y: sizing.y(536))
            }
            .frame(width: sizing.width, height: sizing.height, alignment: .topLeading)
        }
        .sensoryFeedback(.success, trigger: ticks)
        .task { await store.send(.task).finish() }
    }

    @ViewBuilder private var strip: some View {
        if let way = store.way {
            WayStrip(destination: KitSlot(iconName: way.destination), mover: KitSlot(iconName: way.mover),
                     progress: way.progress, homeLabel: way.homeLabel, destinationLabel: way.place,
                     showsStops: way.showsStops, cardTitle: way.cardTitle, cardCaption: way.cardCaption,
                     owner: (KidFace.Badge(face: way.owner.face, colorIndex: way.owner.colorIndex), way.owner.name))
                .accessibilityLabel(way.spoken)
        } else {
            WayStrip(homeAllDay: L10n.tr("missions.home_all_day"))
                .accessibilityLabel(L10n.tr("missions.way.none"))
        }
    }

    private var header: some View {
        HStack(spacing: sizing.space(Spacing.m)) {
            RoundButton(glyph: .chevronLeft, accessibilityLabel: L10n.tr("missions.back")) { store.send(.backTapped) }
            Text(L10n.tr("missions.title")).crayonType(.title).foregroundStyle(CrayonColor.ink)
            Spacer()
            if let way = store.way {
                Text(way.headerPlace).crayonType(.body).foregroundStyle(CrayonColor.softText)
                Text(way.headerMinutes).crayonType(.title).foregroundStyle(CrayonColor.ink)
            }
        }
    }

    private var missionsArea: some View {
        HStack(alignment: .top, spacing: sizing.space(Spacing.m)) {
            VStack(alignment: .leading, spacing: sizing.space(Spacing.s)) {
                ForEach(store.rows) { row in kidRow(row) }
            }
            .frame(width: 340 * sizing.s, alignment: .topLeading)
            VStack(alignment: .leading, spacing: sizing.space(Spacing.m)) {
                if let kid = store.chosenKid {
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.s) {
                        Text(kid.name).crayonType(.head).foregroundStyle(CrayonColor.ink)
                        if let leaveAt = store.leaveAt {
                            Text(leaveAt).crayonType(.body).foregroundStyle(CrayonColor.softText)
                        }
                    }
                    HStack(alignment: .top, spacing: sizing.space(Spacing.m)) {
                        ForEach(store.circles) { circle in missionCircle(circle, colorIndex: kid.colorIndex) }
                    }
                    Spacer(minLength: 0)
                    HStack {
                        Spacer()
                        KidPillButton(store.buttonTitle, icon: .star, colorIndex: kid.colorIndex) {
                            ticks += 1
                            store.send(.allDoneTapped)
                        }
                        // 400 on the board; grows to fit "Back to the clock" rather than cutting it.
                        .frame(minWidth: 400 * sizing.s)
                        .fixedSize()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func kidRow(_ row: MissionsFeature.KidRow) -> some View {
        Button { store.send(.kidTapped(row.kid.id)) } label: {
            HStack(spacing: Spacing.s) {
                ZStack {
                    CrayonRing(progress: row.progress, colorIndex: row.kid.colorIndex, size: 76 * sizing.s)
                    KidFace(KidFace.Badge(face: row.kid.face, colorIndex: row.kid.colorIndex), name: row.kid.name,
                            size: 56 * sizing.s)
                }
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(row.kid.name).crayonType(.body).foregroundStyle(CrayonColor.ink)
                    Text(store.state.caption(row)).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, Spacing.s)
            .frame(width: 340 * sizing.s, height: max(64, 100 * sizing.s))
            .background { if row.id == store.chosen { KidBand(colorIndex: row.kid.colorIndex) } }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(row.id == store.chosen ? [.isButton, .isSelected] : .isButton)
    }

    @ViewBuilder
    private func missionCircle(_ circle: MissionsFeature.Circle, colorIndex: Int) -> some View {
        switch circle {
        case let .mission(mission, isDone, isCurrent):
            Button { store.send(.missionTapped(mission.id)) } label: {
                MissionCircle(picture: KitSlot(iconName: mission.picture), name: mission.name, colorIndex: colorIndex,
                              isDone: isDone, isCurrent: isCurrent)
            }
            .buttonStyle(.plain)
        case let .folded(count):
            MissionCircle(.tick, name: L10n.tr("missions.folded", count), colorIndex: colorIndex)
        case let .more(count):
            Button { store.send(.moreTapped) } label: {
                MissionCircle(.text(L10n.tr("missions.more_count", count)), name: L10n.tr("missions.more", count),
                              colorIndex: colorIndex)
            }
            .buttonStyle(.plain)
        case .back:
            Button { store.send(.backPageTapped) } label: {
                MissionCircle(.glyph(.chevronLeft), name: L10n.tr("missions.page_back"), colorIndex: colorIndex)
            }
            .buttonStyle(.plain)
        }
    }
}
