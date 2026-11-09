import ComposableArchitecture
import CrayonKit
import DesignSystem
import Domain
import KitArt
import Strings
import SwiftUI

/// A2 · Morning (boards A2, A2t, A2t-w, A3): header, the way strip, the kid list and the chosen
/// kid's missions, slide to go or "All done!". Every part is placed from `MorningLayout`.
public struct MissionsView: View {
    let store: StoreOf<MissionsFeature>
    @State private var ticks = 0
    @Environment(\.sizing) private var sizing

    public init(store: StoreOf<MissionsFeature>) {
        self.store = store
    }

    public var body: some View {
        // Spec "A2 redlines" through "Sizing formulas": every part sits on the board's lines
        // (64, 448, 1312; baselines 107, 584, 757). No part's place comes from its content.
        let layout = MorningLayout(sizing: sizing)
        KidFullScreen {
            ZStack(alignment: .topLeading) {
                header(layout)
                strip.place(layout.strip)
                kidList(layout)
                missions(layout)
                bottomControl(layout)
            }
            .frame(width: sizing.width, height: sizing.height, alignment: .topLeading)
        }
        .sensoryFeedback(.success, trigger: ticks)
        .task { await store.send(.task).finish() }
    }

    @ViewBuilder private var strip: some View {
        if let live = store.liveStrip {
            WayStrip(live: live)
                .accessibilityLabel(store.liveSpoken ?? "")
        } else if let trip = store.wayTrip {
            WayStrip(trip: trip)
                .accessibilityLabel(store.way?.spoken ?? "")
        } else {
            WayStrip(homeAllDay: L10n.tr("missions.home_all_day"))
                .accessibilityLabel(L10n.tr("missions.way.none"))
        }
    }

    // MARK: Header (48–128): ← at 64, title at 168, the right group ending at 1312, baseline 107.

    @ViewBuilder private func header(_ layout: MorningLayout) -> some View {
        RoundButton(glyph: .chevronLeft, accessibilityLabel: L10n.tr("missions.back")) { store.send(.backTapped) }
            .place(layout.back)
        Text(store.title).crayonType(.title).foregroundStyle(CrayonColor.ink).lineLimit(1)
            .place(left: layout.titleLeft, baseline: layout.headerBaseline)
        if let header = store.header {
            HStack(alignment: .firstTextBaseline, spacing: sizing.space(Spacing.sm)) {
                Text(header.label).crayonType(.body).foregroundStyle(CrayonColor.softText)
                Text(header.minutes).crayonType(.title).foregroundStyle(CrayonColor.ink)
                if let status = header.status {
                    StatusDot(status.text, tone: Self.tone(status.tone)).padding(.leading, sizing.space(Spacing.xxs))
                }
            }
            .place(right: layout.headerRight, baseline: layout.headerBaseline)
        }
    }

    private static func tone(_ tone: MissionsFeature.StatusLine.Tone) -> StatusDot.Tone {
        switch tone {
        case .onTime: .onTime
        case .hurry: .hurry
        case .quiet: .quiet
        }
    }

    // MARK: Kid list (rows at 536 + 108 i; text at 172)

    @ViewBuilder private func kidList(_ layout: MorningLayout) -> some View {
        ForEach(Array(store.rows.enumerated()), id: \.element.id) { index, row in
            if row.id == store.chosen {
                KidBand(colorIndex: row.kid.colorIndex).place(layout.kidBand(index))
            }
            CrayonRing(progress: row.progress, colorIndex: row.kid.colorIndex, size: layout.kidRing(index).width)
                .place(layout.kidRing(index))
            KidFace(KidFace.Badge(face: row.kid.face, colorIndex: row.kid.colorIndex), name: row.kid.name,
                    size: layout.kidFace(index).width)
                .place(layout.kidFace(index))
            if let medal = row.medal {
                // Board A3: the medal badge on the ring's lower right, dropping in once.
                MedalBadge(medal, ring: layout.kidRing(index).width).place(layout.kidRing(index))
            }
            Text(row.kid.name).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink)
                .place(left: layout.kidTextLeft, baseline: layout.kidNameBaseline(index))
            // Ready rows read "Ready! Gold" in bold on-time green (board A3).
            Text(store.state.caption(row)).crayonType(.caption, bold: row.isReady)
                .foregroundStyle(row.isReady ? CrayonColor.onTimeText : CrayonColor.softText)
                .place(left: layout.kidTextLeft, baseline: layout.kidCaptionBaseline(index))
            Button { store.send(.kidTapped(row.kid.id)) } label: { Color.clear.contentShape(Rectangle()) }
                .buttonStyle(.plain)
                .place(layout.kidRow(index))
                .accessibilityLabel(row.kid.name)
                .accessibilityValue(store.state.caption(row))
                .accessibilityAddTraits(row.id == store.chosen ? [.isButton, .isSelected] : .isButton)
        }
    }

    // MARK: Missions column (448 s … W − 64 s): name line at baseline 584, circles 612–724.

    @ViewBuilder private func missions(_ layout: MorningLayout) -> some View {
        if let kid = store.chosenKid {
            HStack(alignment: .firstTextBaseline, spacing: sizing.space(Spacing.sm)) {
                Text(kid.name).crayonType(.head).foregroundStyle(CrayonColor.ink)
                if let leaveAt = store.leaveAt {
                    Text(leaveAt).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                }
            }
            .place(left: layout.columnLeft, baseline: layout.nameBaseline)
            if let done = store.done {
                // Board A3r: the done view in place of the missions.
                Group {
                    if let medal = done.medal {
                        DroppingMedal(medal, size: layout.doneMedal.width)
                    } else {
                        // It plays its rig once when the done view appears.
                        RiggedKitIcon(done.prize, size: layout.doneMedal.width, playID: store.confetti)
                    }
                }
                .place(layout.doneMedal)
                Text(done.title).crayonType(.display).foregroundStyle(CrayonColor.ink)
                    .place(left: layout.doneTextLeft, baseline: layout.doneTitleBaseline)
                if let subtitle = done.subtitle {
                    Text(subtitle).crayonType(.body).foregroundStyle(CrayonColor.softText)
                        .place(left: layout.doneTextLeft, baseline: layout.doneSubtitleBaseline)
                }
                // Board 0g2: crayon confetti from the medal centre, kept inside the missions column.
                CrayonConfetti(trigger: store.confetti, scale: sizing.s)
                    .position(x: layout.doneMedal.midX - layout.missionsRegion.minX,
                              y: layout.doneMedal.midY - layout.missionsRegion.minY)
                    .frame(width: layout.missionsRegion.width, height: layout.missionsRegion.height)
                    .clipped()
                    .place(layout.missionsRegion)
            } else {
            ForEach(Array(store.circles.enumerated()), id: \.element.id) { index, circle in
                let rect = layout.circleRect(index)
                missionCircle(circle, colorIndex: kid.colorIndex, labelWidth: layout.pitch)
                    .frame(width: layout.pitch, alignment: .top)
                    .offset(x: rect.midX - layout.pitch / 2, y: rect.minY)
            }
            }
        }
    }

    // MARK: Bottom control (872–968): the slide spans the column, 448–1312.

    @ViewBuilder private func bottomControl(_ layout: MorningLayout) -> some View {
        if let kid = store.chosenKid {
            SlideToGo(state: store.chosenIsReady ? .done : .idle, idleTitle: store.slideTitle, doneTitle: L10n.tr("missions.ready"), knob: store.slideKnob,
                      onUndo: { store.send(.slideUndone) }) {
                ticks += 1
                store.send(.slid)
            }
            // A new kid or a new ready state starts the slide afresh.
            .id("\(kid.id)-\(store.chosenIsReady)")
            .place(layout.slide)
        }
    }

    @ViewBuilder
    private func missionCircle(_ circle: MissionsFeature.Circle, colorIndex: Int, labelWidth: CGFloat) -> some View {
        switch circle {
        case let .mission(mission, isDone, isCurrent):
            Button { store.send(.missionTapped(mission.id)) } label: {
                MissionCircle(picture: KitSlot(iconName: mission.picture), name: mission.name, colorIndex: colorIndex,
                              isDone: isDone, isCurrent: isCurrent, labelWidth: labelWidth,
                              playID: store.plays[mission.id] ?? 0)
            }
            .buttonStyle(.plain)
        case let .folded(count):
            MissionCircle(.tick, name: L10n.tr("missions.folded", count), colorIndex: colorIndex, labelWidth: labelWidth)
        case let .more(count):
            Button { store.send(.moreTapped) } label: {
                MissionCircle(.text(L10n.tr("missions.more_count", count)), name: L10n.tr("missions.more", count),
                              colorIndex: colorIndex, labelWidth: labelWidth)
            }
            .buttonStyle(.plain)
        case .back:
            Button { store.send(.backPageTapped) } label: {
                MissionCircle(.glyph(.chevronLeft), name: L10n.tr("missions.page_back"), colorIndex: colorIndex,
                              labelWidth: labelWidth)
            }
            .buttonStyle(.plain)
        }
    }
}
