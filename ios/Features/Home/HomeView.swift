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
    @State private var holdProgress = 0.0
    @State private var holdStarted = 0
    @State private var holdCompleted = 0

    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }

    public var body: some View {
        KidFullScreen(look: store.look, wipeFrom: store.isSkyAnimating ? Self.skySwitchCentre : nil) {
            // Board A1: clock area x 0–900, right panel x 928–1312 from y 96.
            HStack(alignment: .top, spacing: 28) {
                clockArea
                rightPanel
                    .frame(width: 384, alignment: .leading)
                    .padding(.top, 96)
                Spacer(minLength: 0)
            }
        }
        .simultaneousGesture(TapGesture().onEnded { store.send(.touched) })
        .task { await store.send(.task).finish() }
        .sensoryFeedback(.impact(weight: .light), trigger: holdStarted)
        .sensoryFeedback(.success, trigger: holdCompleted)
    }

    private var firstDay: HomeFeature.KidDay? { store.days.first }

    /// Board 0g: the switch sits at x 40, y 36 of the clock area, clear of the hour labels.
    private static let skySwitchOrigin = CGPoint(x: 40, y: 36)
    private static let skySwitchCentre = CGPoint(x: 40 + SkySwitch.size.width / 2, y: 36 + SkySwitch.size.height / 2)

    // MARK: Clock

    private var clockArea: some View {
        let slots = firstDay?.slots ?? []
        return PieClock(sectors: HomeModel.sectors(slots, minute: store.minute),
                        now: slots.isEmpty ? nil : store.minute,
                        hub: HomeModel.hub(slots, minute: store.minute),
                        holdProgress: holdProgress, look: store.look,
                        motion: PieClock.Motion(slotStart: store.currentSlotStart, hour: store.hour,
                                                winks: store.winks))
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
            .frame(width: 900, height: 1032)
            .overlay(alignment: .topLeading) {
                SkySwitch(look: store.look, isAnimating: store.isSkyAnimating, label: store.skySwitchLabel) {
                    store.send(.skySwitchTapped)
                }
                .offset(x: Self.skySwitchOrigin.x, y: Self.skySwitchOrigin.y)
            }
    }

    // MARK: Right panel

    @ViewBuilder private var rightPanel: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            if let first = firstDay {
                // The weekday heads the panel on every kid home screen, 24 above Kid A.
                VStack(alignment: .leading, spacing: Spacing.m) {
                    if let heading = store.dayHeading {
                        Text(heading).crayonType(.head).foregroundStyle(store.look.ink)
                    }
                    kidABlock(first)
                }
                if store.days.count > 1 {
                    kidBBlock(store.days[1])
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
            if let next {
                Text(L10n.tr("home.next")).crayonType(.caption).foregroundStyle(store.look.softText)
                    .padding(.top, 24)
                nextRow(next).padding(.top, 8)
            }
            if let timeLeft {
                Text(timeLeft.label).crayonType(.body).foregroundStyle(store.look.softText)
                    .padding(.top, 24)
                TimeLeft(minutes: timeLeft.minutes, look: store.look)
            }
        }
    }

    private func kidBBlock(_ day: HomeFeature.KidDay) -> some View {
        let now = DayPlanner.now(at: store.minute, in: day.slots)
        return VStack(alignment: .leading, spacing: Spacing.m) {
            kidHeader(day.kid)
            KidNowNext(now: now.current?.iconName ?? "actPlay", next: now.next?.iconName, look: store.look)
        }
    }

    private func nextRow(_ row: NextRow) -> some View {
        HStack(spacing: 20) {
            KitPlate(look: store.look, size: 104) {
                KitIcon(KitSlot(rawValue: row.iconName) ?? .actPlay, size: 104)
                    .overlay(alignment: .topTrailing) {
                        if row.showsStar { KitIcon(.star, size: 36) }
                    }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(row.title).crayonType(.head).foregroundStyle(store.look.ink)
                    .lineLimit(1).truncationMode(.tail)
                Text(row.at).crayonType(.body).foregroundStyle(store.look.softText).lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
