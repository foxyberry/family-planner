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
        KidFullScreen(look: store.look, wipeFrom: store.isSkyAnimating ? skySwitchCentre : nil) {
            // Boards A1 / A1m / E1 (docs/superpowers/layout), board × s: every part placed from
            // HomeLayout; the panel's parts all start on 928 and end on 1336 (layout v29).
            let layout = HomeLayout(sizing: sizing, dayNote: store.hasDayNote)
            ZStack(alignment: .topLeading) {
                clockArea
                    .position(layout.clockCentre)
                SkySwitch(look: store.look, isAnimating: store.isSkyAnimating) {
                    store.send(.skySwitchTapped)
                }
                .place(topLeft: layout.skySwitch.origin)
                panel(layout)
                // Board G0 (layout v74): the school calendar (K1), no lock, left of the pencil.
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

    private var firstDay: HomeFeature.KidDay? { store.days.first }

    /// The night wipe starts from the sky switch's centre (board 0g).
    private var skySwitchCentre: CGPoint {
        let frame = HomeLayout(sizing: sizing).skySwitch
        return CGPoint(x: frame.midX, y: frame.midY)
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
        PieClock(sectors: store.clockSectors, now: store.clockHand, hub: store.clockHub,
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

    // MARK: Right panel (928–1336, × s)

    @ViewBuilder private func panel(_ layout: HomeLayout) -> some View {
        if let first = firstDay {
            if let heading = store.dayHeading {
                // Spec "Hub text" (board E3h): red on a public holiday, with its name (or a school
                // break's) as a caption under it.
                Text(heading).crayonType(.head).foregroundStyle(store.look.text(late: store.isPublicHoliday))
                    .lineLimit(1)
                    .place(left: layout.panelLeft, baseline: layout.weekdayBaseline)
            }
            if let note = store.dayNote {
                Text(note).crayonType(.caption).foregroundStyle(store.look.softText).lineLimit(1)
                    .place(left: layout.panelLeft, baseline: layout.dayNoteBaseline)
            }
            kidHeader(first.kid, top: layout.kidATop, layout: layout)
            kidABlock(layout: layout)
            if let kidB = store.kidB {
                let top = layout.kidBTop(after: store.kidAEnd)
                kidHeader(kidB.kid, top: top, layout: layout)
                // Layout v73: a Now row and a Next row in the row shape, 96 apart.
                NextRow(picture: kidB.now.picture, caption: store.nowLabel, title: kidB.now.title,
                        line: kidB.now.line, showsStar: kidB.now.showsStar, look: store.look)
                    .place(topLeft: layout.kidBNowRow(kidBTop: top).picture.origin)
                if let next = kidB.next {
                    nextRow(next, at: layout.kidBNextRow(kidBTop: top))
                }
            } else if let next = store.leaveNext {
                nextRow(next, at: layout.leaveNextRow)
            }
            if store.showsMissions {
                InkButton(store.missionsTitle, arrow: true, look: store.look) { store.send(.missionsTapped) }
                    .place(layout.button)
            }
        }
    }

    private func kidHeader(_ kid: Kid, top: CGFloat, layout: HomeLayout) -> some View {
        ZStack(alignment: .topLeading) {
            KidFace(KidFace.Badge(face: kid.face, colorIndex: kid.colorIndex),
                    size: layout.kidBadge(top: top).width)
                .place(layout.kidBadge(top: top))
            Text(kid.name).crayonType(.head).foregroundStyle(store.look.ink).lineLimit(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .place(layout.kidName(top: top))
        }
    }

    /// Kid A (spec "Home panel lines", layout v73): one row under the name, the picture on
    /// the left and the words stacked to its right. Leave (A1), bed time (A1n), or the Next row (E3).
    @ViewBuilder private func kidABlock(layout: HomeLayout) -> some View {
        switch store.kidABlock {
        case .leave:
            if let picture = store.leavePicture, let left = store.leaveTimeLeft {
                KitPlate(look: store.look, size: layout.kidAPicture.width, nightPicture: 56.0 / 80.0) {
                    KitIcon(picture, size: layout.kidAPicture.width)
                }
                .place(layout.kidAPicture)
                timeLeft(left, layout: layout)
                if let status = store.status {
                    StatusDot(status.text, tone: status.tone, compact: true)
                        .place(left: layout.kidATextLeft, baseline: layout.kidAStatusBaseline)
                }
            }
        case let .bedTime(left, tomorrow):
            // Board A1n (layout v74): the moon (56) on an 80 night plate.
            KitPlate(look: store.look, size: layout.kidAPicture.width, nightPicture: 56.0 / 80.0) {
                KitIcon(.actSleep, size: layout.kidAPicture.width)
            }
            .place(layout.kidAPicture)
            timeLeft(left, layout: layout)
            if let tomorrow {
                // The Tomorrow row, 104 below the Bed row.
                aheadRow(tomorrow, at: layout.timeLeftRow)
            }
        case let .next(next):
            nextRow(next, at: layout.nextRow)
        case let .tomorrow(row):
            // Board A1z: the next day's first outing or first thing.
            aheadRow(row, at: layout.nextRow)
        case .nothing:
            EmptyView()
        }
    }

    /// "Leave in" / "Bed in" (caption, soft) over the time left (48), right of the picture (layout v73).
    @ViewBuilder private func timeLeft(_ left: HomeModel.TimeLeft, layout: HomeLayout) -> some View {
        Text(left.label).crayonType(.caption).foregroundStyle(store.look.softText).lineLimit(1)
            .place(left: layout.kidATextLeft, baseline: layout.kidALabelBaseline)
        TimeLeft(left.text, isLate: left.isLate, look: store.look, compact: true)
            .place(left: layout.kidATextLeft, baseline: layout.kidATimeBaseline)
    }

    /// Boards A1n, A1z: the Tomorrow row ("Tomorrow · School" / "leave 7:25 am").
    private func aheadRow(_ row: AheadRow, at place: HomeLayout.RowPlace) -> some View {
        NextRow(picture: row.item.picture, caption: store.state.aheadCaption(row), title: row.item.title,
                line: row.item.line, showsStar: row.item.showsStar, look: store.look)
            .place(topLeft: place.picture.origin)
    }

    /// The Next row (the `NextRow` part): the picture (104), then "Next", its title and the time line.
    private func nextRow(_ item: NextItem, at place: HomeLayout.RowPlace) -> some View {
        NextRow(picture: item.picture, caption: store.nextLabel, title: item.title, line: item.line,
                showsStar: item.showsStar, look: store.look)
            .place(topLeft: place.picture.origin)
    }
}
