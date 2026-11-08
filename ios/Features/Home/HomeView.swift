import ComposableArchitecture
import CrayonKit
import DesignSystem
import Domain
import KitArt
import Strings
import SwiftUI

/// The kids' home screen (boards A1, E1, E3). Kids never scroll here: the lists are capped.
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
            // Board A1 through spec "Sizing formulas": the clock (R 372 s) centred at
            // (448 s, y(528)); the sky switch at (40 s, y(36)); the right panel stretches from
            // 928 s to W − 64 s, y(96) … y(968).
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

    /// Board 0g: the switch sits at x 40, y 36 of the clock area, clear of the hour labels.
    private static let skySwitchOrigin = CGPoint(x: 40, y: 36)
    private var skySwitchCentre: CGPoint {
        CGPoint(x: Self.skySwitchOrigin.x * sizing.s + SkySwitch.size.width / 2,
                y: sizing.y(Self.skySwitchOrigin.y) + SkySwitch.size.height / 2)
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
            kidABlock(first, layout: layout)
            if store.days.count > 1 {
                let top = layout.kidBTop(hasStatus: store.status != nil)
                kidHeader(store.days[1].kid, top: top, layout: layout)
                let now = DayPlanner.now(at: store.minute, in: store.days[1].slots)
                KidNowNext(now: now.current?.iconName ?? "actPlay", next: now.next?.iconName, look: store.look)
                    .place(topLeft: layout.nowNext(kidBTop: top))
            } else if let next = HomeModel.next(first.slots, minute: store.minute) {
                // E1, one kid: the Next row under Kid A.
                Text(L10n.tr("home.next")).crayonType(.caption).foregroundStyle(store.look.softText)
                    .place(left: layout.panelLeft, baseline: layout.nextLabelBaseline)
                nextRow(next, layout: layout)
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
            Text(kid.name).crayonType(.head).foregroundStyle(store.look.ink)
                .place(left: layout.kidNameLeft, baseline: layout.kidNameBaseline(top: top))
        }
    }

    /// Kid A: "Leave in" (or "{next} in") with the way picture, the minutes, and the live status.
    @ViewBuilder private func kidABlock(_ day: HomeFeature.KidDay, layout: HomeLayout) -> some View {
        if let outing = store.morningOuting, let heading = store.outingHeading {
            Text(heading).crayonType(.body).foregroundStyle(store.look.softText)
                .place(left: layout.panelLeft, baseline: layout.labelBaseline)
            KitPlate(look: store.look, size: layout.way.width) {
                KitIcon(KitSlot(iconName: outing.trip.way.moverPicture), size: layout.way.width)
            }
            .place(layout.way)
            TimeLeft(minutes: store.minutesToLeave ?? outing.slot.start - store.minute, look: store.look)
                .place(left: layout.panelLeft, baseline: layout.timeBaseline)
            if let status = store.status {
                StatusDot(status.text, tone: status.tone)
                    .place(left: layout.panelLeft, baseline: layout.statusBaseline)
            }
        } else if let timeLeft = HomeModel.timeLeft(to: HomeModel.next(day.slots, minute: store.minute),
                                                    minute: store.minute) {
            Text(timeLeft.label).crayonType(.body).foregroundStyle(store.look.softText)
                .place(left: layout.panelLeft, baseline: layout.labelBaseline)
            TimeLeft(minutes: timeLeft.minutes, look: store.look)
                .place(left: layout.panelLeft, baseline: layout.timeBaseline)
        }
    }

    /// E1: the next picture (104) at 928, its title and time on their baselines at 1056.
    @ViewBuilder private func nextRow(_ row: NextRow, layout: HomeLayout) -> some View {
        KitPlate(look: store.look, size: layout.nextPicture.width) {
            KitIcon(KitSlot(rawValue: row.iconName) ?? .actPlay, size: layout.nextPicture.width)
                .overlay(alignment: .topTrailing) {
                    if row.showsStar { KitIcon(.star, size: 36 * sizing.s) }
                }
        }
        .place(layout.nextPicture)
        Text(row.title).crayonType(.head).foregroundStyle(store.look.ink).lineLimit(1)
            .place(left: layout.nextTextLeft, baseline: layout.nextTitleBaseline)
        Text(row.at).crayonType(.body).foregroundStyle(store.look.softText).lineLimit(1)
            .place(left: layout.nextTextLeft, baseline: layout.nextTimeBaseline)
    }
}
