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
            ZStack(alignment: .topLeading) {
                clockArea
                    .position(x: 448 * sizing.s, y: sizing.y(528))
                SkySwitch(look: store.look, isAnimating: store.isSkyAnimating, label: store.skySwitchLabel) {
                    store.send(.skySwitchTapped)
                }
                .offset(x: Self.skySwitchOrigin.x * sizing.s, y: sizing.y(Self.skySwitchOrigin.y))
                rightPanel
                    .frame(width: sizing.width - 64 * sizing.s - 928 * sizing.s,
                           height: (968 - 96) * sizing.s, alignment: .topLeading)
                    .offset(x: 928 * sizing.s, y: sizing.y(96))
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

    // MARK: Right panel

    @ViewBuilder private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let first = firstDay {
                VStack(alignment: .leading, spacing: sizing.space(Spacing.xl)) {
                    // The weekday heads the panel on every kid home screen, 24 above Kid A.
                    VStack(alignment: .leading, spacing: sizing.space(Spacing.m)) {
                        if let heading = store.dayHeading {
                            Text(heading).crayonType(.head).foregroundStyle(store.look.ink)
                        }
                        kidABlock(first)
                    }
                    if store.days.count > 1 {
                        kidBBlock(store.days[1])
                    }
                }
                if store.isMissionMorning {
                    // Spec A1 "Panel fit": flexible space pins the button to the panel bottom and
                    // gives way first, down to 24.
                    Spacer(minLength: sizing.space(Spacing.m))
                    InkButton(L10n.tr("home.missions"), arrow: true) { store.send(.missionsTapped) }
                }
            }
        }
    }

    private func kidHeader(_ kid: Kid) -> some View {
        HStack(spacing: KidFace.gap(for: KidFace.large)) {
            KidFace(KidFace.Badge(face: kid.face, colorIndex: kid.colorIndex), name: kid.name)
                .accessibilityHidden(true)
            Text(kid.name).crayonType(.head).foregroundStyle(store.look.ink)
        }
    }

    /// Spec "Now and next on home": the clock kid's now is the hub, so this block shows only Next
    /// (one row, the start time) and the time left to it.
    private func kidABlock(_ day: HomeFeature.KidDay) -> some View {
        let next = HomeModel.next(day.slots, minute: store.minute)
        let timeLeft = HomeModel.timeLeft(to: next, minute: store.minute)
        return VStack(alignment: .leading, spacing: 0) {
            kidHeader(day.kid)
            if let outing = store.morningOuting, let heading = store.outingHeading {
                // Board A1-MVP: "{Place} in" with the way picture, then the minutes to the start.
                HStack(alignment: .center) {
                    Text(heading).crayonType(.body).foregroundStyle(store.look.softText)
                    Spacer(minLength: sizing.space(Spacing.s))
                    KitPlate(look: store.look, size: 80 * sizing.s) {
                        KitIcon(KitSlot(iconName: outing.trip.way.moverPicture), size: 80 * sizing.s)
                    }
                }
                .padding(.top, sizing.space(Spacing.m))
                TimeLeft(minutes: outing.slot.start - store.minute, look: store.look)
            } else if let next {
                Text(L10n.tr("home.next")).crayonType(.caption).foregroundStyle(store.look.softText)
                    .padding(.top, sizing.space(Spacing.m))
                nextRow(next).padding(.top, sizing.space(Spacing.xs))
            }
            if store.morningOuting == nil, !store.isMissionMorning, let timeLeft {
                Text(timeLeft.label).crayonType(.body).foregroundStyle(store.look.softText)
                    .padding(.top, sizing.space(Spacing.m))
                TimeLeft(minutes: timeLeft.minutes, look: store.look)
            }
        }
    }

    private func kidBBlock(_ day: HomeFeature.KidDay) -> some View {
        let now = DayPlanner.now(at: store.minute, in: day.slots)
        return VStack(alignment: .leading, spacing: sizing.space(Spacing.m)) {
            kidHeader(day.kid)
            KidNowNext(now: now.current?.iconName ?? "actPlay", next: now.next?.iconName, look: store.look)
        }
    }

    private func nextRow(_ row: NextRow) -> some View {
        HStack(spacing: sizing.space(Spacing.m)) {
            KitPlate(look: store.look, size: 104 * sizing.s) {
                KitIcon(KitSlot(rawValue: row.iconName) ?? .actPlay, size: 104 * sizing.s)
                    .overlay(alignment: .topTrailing) {
                        if row.showsStar { KitIcon(.star, size: 36) }
                    }
            }
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(row.title).crayonType(.head).foregroundStyle(store.look.ink)
                    .lineLimit(1).truncationMode(.tail)
                Text(row.at).crayonType(.body).foregroundStyle(store.look.softText).lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
