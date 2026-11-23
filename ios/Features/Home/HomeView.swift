import ComposableArchitecture
import CrayonKit
import DesignSystem
import Domain
import KitArt
import SwiftUI

/// The kids' home screen (boards A1, A1m, A1n, E1, E3, E3b, E3h). Kids never scroll here: the lists are capped.
public struct HomeView: View {
    let store: StoreOf<HomeFeature>
    @Environment(\.rigScale) private var rigScale
    @Environment(\.sizing) private var sizing
    @State private var holdProgress = 0.0
    @State private var holdStarted = 0
    @State private var holdCompleted = 0
    /// Where the press on the clock began (view-only; the slice under it goes to the store on completion).
    @State private var pressLocation: CGPoint?

    public init(store: StoreOf<HomeFeature>) {
        self.store = store
    }

    public var body: some View {
        KidFullScreen(look: store.look, wipeFrom: HomeLayout(sizing: sizing).skyWipe(store.isSkyAnimating)) {
            // Boards A1 / A1k / E1 (layout v75), board × s: every part placed from HomeLayout.
            let layout = HomeLayout(sizing: sizing)
            ZStack(alignment: .topLeading) {
                clockArea
                    .position(layout.clockCentre)
                SkySwitch(look: store.look, isAnimating: store.isSkyAnimating) {
                    store.send(.skySwitchTapped)
                }
                .place(topLeft: layout.skySwitch.origin)
                panel(layout)
                // Board G0 (layout v75): the school calendar (K1), no lock, left of the pencil.
                RoundButton(picture: .calendar) {
                    store.send(.calendarTapped)
                }
                .size(96)
                .look(store.look)
                .place(topLeft: layout.calendarButton.origin)
                // Board G0: the way into grown-up mode, the same by day and night.
                RoundButton(picture: .pencil) {
                    store.send(.pencilTapped)
                }
                .size(96)
                .look(store.look)
                .place(topLeft: layout.pencil.origin)
            }
            .frame(width: sizing.width, height: sizing.height, alignment: .topLeading)
        }
        .simultaneousGesture(TapGesture().onEnded { store.send(.touched) })
        .simultaneousGesture(pressWatcher)
        .task { await store.send(.task).finish() }
        .sensoryFeedback(.impact(weight: .light), trigger: holdStarted)
        .sensoryFeedback(.success, trigger: holdCompleted)
    }

    // MARK: Clock

    /// Where a press began, in the clock's own space (its centre at R s, R s). It watches from the
    /// whole screen: a gesture on the clock itself stopped the 2-second hold from finishing (iPad,
    /// 2026-11-14).
    private var pressWatcher: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                guard pressLocation == nil else { return }
                // Global x counts the paper beside the board frame (`bleed`) too.
                let centre = HomeLayout(sizing: sizing).clockCentre, r = PieClock.radius * sizing.s
                pressLocation = CGPoint(x: value.startLocation.x - sizing.bleed - centre.x + r,
                                        y: value.startLocation.y - centre.y + r)
            }
            .onEnded { _ in pressLocation = nil }
    }

    private var clockArea: some View {
        PieClock(sectors: store.clockSectors, now: store.clockHand, hub: store.clockHub, rim: store.clockRim,
                        holdProgress: holdProgress, look: store.look,
                        motion: PieClock.Motion(slotStart: store.currentSlotStart, hour: store.hour,
                                                winks: store.winks),
                        plays: store.plays, rigScale: rigScale)
            .onTapGesture(coordinateSpace: .local) { location in
                if let start = PieClock.slotStart(at: location, in: store.clockSectors, scale: sizing.s) {
                    store.send(.slotTapped(start))
                }
            }
            .contentShape(Circle())
            .onLongPressGesture(minimumDuration: 2) {
                holdCompleted += 1
                store.send(.clockPressed(slotStart: pressLocation.flatMap {
                    PieClock.slotStart(at: $0, in: store.clockSectors, scale: sizing.s)
                }))
                store.send(.clockHoldCompleted)
            } onPressingChanged: { pressing in
                if pressing {
                    holdStarted += 1
                    withAnimation(.linear(duration: 2)) { holdProgress = 1 }
                } else {
                    withAnimation(.easeOut(duration: 0.2)) { holdProgress = 0 }
                }
            }
    }

    // MARK: Right panel (928–1336, × s), bottom up (spec A1 "Next things", "Kid chips")

    @ViewBuilder private func panel(_ layout: HomeLayout) -> some View {
        ForEach(Array(store.laterRows.enumerated()), id: \.element.id) { index, thing in
            row(thing, size: .row).place(layout.row(index, of: store.laterRowKinds))
        }
        if let card = store.nextCard {
            row(card, size: .card).place(layout.card)
        }
        ForEach(Array(store.chips.enumerated()), id: \.element.id) { index, chip in
            KidChip(face: chip.face, picture: chip.picture, name: chip.name, isPicked: chip.isPicked, look: store.look) {
                store.send(.kidChipTapped(chip.id))
            }
            .place(layout.chip(index, of: store.chips.count))
        }
    }

    /// One family row or the next card; a mission row opens A2 for its kid.
    @ViewBuilder private func row(_ thing: NextThing, size: NextThingRow.Size) -> some View {
        let part = NextThingRow(time: store.state.timeCell(thing), picture: thing.picture, title: thing.title,
                                faces: store.state.faces(thing), hatch: store.state.hatch(thing), size: size,
                                faded: store.state.isFaded(thing), look: store.look)
        if let kid = thing.missionKids.first {
            Button { store.send(.missionRowTapped(kid)) } label: { part }
                .buttonStyle(.plain)
        } else {
            part.allowsHitTesting(false)
        }
    }
}
