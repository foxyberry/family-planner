import ComposableArchitecture
import CrayonKit
import DesignSystem
import Domain
import KitArt
import Strings
import SwiftUI

/// The kids' home screen (boards A1, A1m, A1n, E1, E3, E3b). Kids never scroll here: the lists are capped.
public struct HomeView: View {
    let store: StoreOf<HomeFeature>
    @Environment(\.rigScale) private var rigScale
    @Environment(\.sizing) private var sizing
    @State private var holdProgress = 0.0
    @State private var holdStarted = 0
    @State private var holdCompleted = 0

    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }

    public var body: some View {
        KidFullScreen(look: store.look, wipeFrom: store.isSkyAnimating ? skySwitchCentre : nil) {
            // Boards A1 / A1m / E1 (docs/superpowers/layout) through "Sizing formulas": every part
            // placed from HomeLayout; the panel's parts all start on 928 and end on 1312.
            let layout = HomeLayout(sizing: sizing)
            ZStack(alignment: .topLeading) {
                clockArea
                    .position(layout.clockCentre)
                SkySwitch(look: store.look, isAnimating: store.isSkyAnimating, label: store.skySwitchLabel) {
                    store.send(.skySwitchTapped)
                }
                .place(topLeft: layout.skySwitch.origin)
                panel(layout)
            }
            .frame(width: sizing.width, height: sizing.height, alignment: .topLeading)
        }
        .simultaneousGesture(TapGesture().onEnded { store.send(.touched) })
        .task { await store.send(.task).finish() }
        .sensoryFeedback(.impact(weight: .light), trigger: holdStarted)
        .sensoryFeedback(.success, trigger: holdCompleted)
    }

    private var firstDay: HomeFeature.KidDay? { store.days.first }

    /// The night wipe starts from the sky switch's centre (board 0g).
    private var skySwitchCentre: CGPoint {
        let origin = HomeLayout(sizing: sizing).skySwitch.origin
        return CGPoint(x: origin.x + SkySwitch.size.width / 2, y: origin.y + SkySwitch.size.height / 2)
    }

    // MARK: Clock

    private var clockArea: some View {
        let slots = firstDay?.slots ?? []
        return PieClock(sectors: HomeModel.sectors(slots, minute: store.minute),
                        now: slots.isEmpty ? nil : store.minute,
                        hub: HomeModel.hub(slots, minute: store.minute),
                        holdProgress: holdProgress, look: store.look,
                        motion: PieClock.Motion(slotStart: store.currentSlotStart, hour: store.hour,
                                                winks: store.winks),
                        plays: store.plays, rigScale: rigScale)
            .onTapGesture(coordinateSpace: .local) { location in
                if let start = PieClock.slotStart(at: location, in: HomeModel.sectors(slots, minute: store.minute),
                                                  scale: sizing.s) {
                    store.send(.slotTapped(start))
                }
            }
            .contentShape(Circle())
            .onLongPressGesture(minimumDuration: 2) {
                holdCompleted += 1
                store.send(.clockHoldCompleted)
            } onPressingChanged: { pressing in
                if pressing {
                    holdStarted += 1
                    withAnimation(.linear(duration: 2)) { holdProgress = 1 }
                } else {
                    withAnimation(.easeOut(duration: 0.2)) { holdProgress = 0 }
                }
            }
            .accessibilityElement()
            .accessibilityLabel(HomeModel.accessibilityLabel(kidName: firstDay?.kid.name ?? "", day: store.dayName ?? "",
                                                             slots: slots,
                                                             minute: store.minute))
    }

    // MARK: Right panel (928 s … W − 64 s)

    @ViewBuilder private func panel(_ layout: HomeLayout) -> some View {
        if let first = firstDay {
            if let heading = store.dayHeading {
                Text(heading).crayonType(.head).foregroundStyle(store.look.ink)
                    .place(left: layout.panelLeft, baseline: layout.weekdayBaseline)
            }
            kidHeader(first.kid, top: layout.kidATop, layout: layout)
            kidABlock(layout: layout)
            if store.days.count > 1 {
                let top = layout.kidBTop(after: store.kidAEnd)
                kidHeader(store.days[1].kid, top: top, layout: layout)
                let now = DayPlanner.now(at: store.minute, in: store.days[1].slots)
                KidNowNext(now: now.current?.iconName ?? "actPlay", next: now.next?.iconName, look: store.look)
                    .place(topLeft: layout.nowNext(kidBTop: top))
            } else if let next = store.leaveNext {
                nextRow(next, at: layout.leaveNextRow)
            }
            if store.isMissionMorning {
                InkButton(L10n.tr("home.missions"), arrow: true) { store.send(.missionsTapped) }
                    .place(layout.button)
            }
        }
    }

    private func kidHeader(_ kid: Kid, top: CGFloat, layout: HomeLayout) -> some View {
        ZStack(alignment: .topLeading) {
            KidFace(KidFace.Badge(face: kid.face, colorIndex: kid.colorIndex), name: kid.name,
                    size: layout.kidBadge(top: top).width)
                .accessibilityHidden(true)
                .place(layout.kidBadge(top: top))
            Text(kid.name).crayonType(.head).foregroundStyle(store.look.ink).lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .place(layout.kidName(top: top))
        }
    }

    /// Kid A, look ① (spec "Home panel lines", layout v17): one row under the name, the picture on
    /// the left and the words stacked to its right. Leave (A1), time left over the small row (A1n by
    /// day), bed time (A1n), or the Next row (E3).
    @ViewBuilder private func kidABlock(layout: HomeLayout) -> some View {
        switch store.kidABlock {
        case .leave:
            if let outing = store.morningOuting, let heading = store.outingHeading {
                KitPlate(look: store.look, size: layout.kidAPicture.width) {
                    KitIcon(KitSlot(iconName: outing.trip.way.moverPicture), size: layout.kidAPicture.width)
                }
                .place(layout.kidAPicture)
                timeLeft(label: heading, minutes: store.minutesToLeave ?? 0, layout: layout)
                if let status = store.status {
                    StatusDot(status.text, tone: status.tone)
                        .place(left: layout.kidATextLeft, baseline: layout.kidAStatusBaseline)
                }
            }
        case let .timeLeft(left, next):
            KitPlate(look: store.look, size: layout.kidAPicture.width) {
                KitIcon(KitSlot(rawValue: next.iconName) ?? .actPlay, size: layout.kidAPicture.width)
            }
            .place(layout.kidAPicture)
            timeLeft(label: left.label, minutes: left.minutes, layout: layout)
            smallRow(icon: next.iconName, title: next.title, line: next.at, layout: layout)
        case let .bedTime(left, tomorrow):
            // Board A1n: the moon (64) on a 96 plate.
            KitPlate(look: store.look, size: layout.kidAPicture.width, nightPicture: 64.0 / 96.0) {
                KitIcon(.actSleep, size: layout.kidAPicture.width)
            }
            .place(layout.kidAPicture)
            timeLeft(label: left.label, minutes: left.minutes, layout: layout)
            if let tomorrow {
                smallRow(icon: tomorrow.iconName, title: tomorrow.title, line: tomorrow.line, layout: layout)
            }
        case let .next(next):
            nextRow(next, at: layout.nextRow)
        case .nothing:
            EmptyView()
        }
    }

    /// "Leave in" / "Bed in" / "in" (body, soft) over the time left (72), right of the picture.
    @ViewBuilder private func timeLeft(label: String, minutes: Int, layout: HomeLayout) -> some View {
        Text(label).crayonType(.body).foregroundStyle(store.look.softText).lineLimit(1)
            .place(left: layout.kidATextLeft, baseline: layout.kidALabelBaseline)
        TimeLeft(minutes: minutes, look: store.look, compact: true)
            .place(left: layout.kidATextLeft, baseline: layout.kidATimeBaseline)
    }

    /// A1n: the 80 row under the time left (Tomorrow, or Next by day): a 56 picture on an 80 plate,
    /// its title (body bold) over its line (caption).
    @ViewBuilder private func smallRow(icon: String, title: String, line: String, layout: HomeLayout) -> some View {
        let place = layout.timeLeftRow
        KitPlate(look: store.look, size: place.picture.width, nightPicture: 56.0 / 80.0) {
            KitIcon(KitSlot(rawValue: icon) ?? .actPlay, size: place.picture.width)
        }
        .place(place.picture)
        Text(title).crayonType(.body, bold: true).foregroundStyle(store.look.ink).lineLimit(1)
            .place(left: place.textLeft, baseline: place.titleBaseline)
        Text(line).crayonType(.caption).foregroundStyle(store.look.softText).lineLimit(1)
            .place(left: place.textLeft, baseline: place.atBaseline)
    }

    /// The Next row: the picture (104), then "Next" (caption), its title and "at …" to its right.
    @ViewBuilder private func nextRow(_ row: NextRow, at place: HomeLayout.RowPlace) -> some View {
        if let labelBaseline = place.labelBaseline {
            Text(L10n.tr("home.next")).crayonType(.caption).foregroundStyle(store.look.softText)
                .place(left: place.textLeft, baseline: labelBaseline)
        }
        KitPlate(look: store.look, size: place.picture.width) {
            KitIcon(KitSlot(rawValue: row.iconName) ?? .actPlay, size: place.picture.width)
                .overlay(alignment: .topTrailing) {
                    if row.showsStar { KitIcon(.star, size: 36 * sizing.s) }
                }
        }
        .place(place.picture)
        Text(row.title).crayonType(.head).foregroundStyle(store.look.ink).lineLimit(1)
            .place(left: place.textLeft, baseline: place.titleBaseline)
        Text(row.at).crayonType(.body).foregroundStyle(store.look.softText).lineLimit(1)
            .place(left: place.textLeft, baseline: place.atBaseline)
    }
}
