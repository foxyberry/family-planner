import ComposableArchitecture
import CrayonKit
import DesignSystem
import Domain
import KitArt
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
        HStack(alignment: .top, spacing: 28) {
            clockArea
            rightPanel
                .frame(width: 384, alignment: .leading)
                .padding(.top, 96)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(CrayonColor.paper.ignoresSafeArea())
        .task { await store.send(.task).finish() }
        .sensoryFeedback(.impact(weight: .light), trigger: holdStarted)
        .sensoryFeedback(.success, trigger: holdCompleted)
    }

    private var firstDay: HomeFeature.KidDay? { store.days.first }

    // MARK: Clock

    private var clockArea: some View {
        let slots = firstDay?.slots ?? []
        return PieClock(sectors: HomeModel.sectors(slots, minute: store.minute),
                        now: slots.isEmpty ? nil : store.minute,
                        hub: HomeModel.hub(slots, minute: store.minute),
                        holdProgress: holdProgress)
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
            .accessibilityLabel(HomeModel.accessibilityLabel(kidName: firstDay?.kid.name ?? "", slots: slots,
                                                             minute: store.minute))
            .frame(width: 900, height: 1032)
    }

    // MARK: Right panel

    @ViewBuilder private var rightPanel: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            if let first = firstDay {
                switch store.layout {
                case .twoKids, .oneKid:
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        kidHeader(first.kid)
                        nextList(first.slots)
                    }
                case .dayOff:
                    dayOffBlock(first)
                }
                if store.days.count > 1 {
                    kidBBlock(store.days[1])
                }
            }
        }
    }

    private func kidHeader(_ kid: Kid) -> some View {
        HStack(spacing: Spacing.s) {
            KidDot(color: CrayonColor.kid(kid.colorIndex))
            Text(kid.name).crayonType(.head).foregroundStyle(CrayonColor.ink)
        }
    }

    private func nextList(_ slots: [Slot]) -> some View {
        let rows = HomeModel.nextRows(slots, minute: store.minute)
        return VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Next").crayonType(.head).foregroundStyle(CrayonColor.ink)
            if rows.isEmpty {
                Text("Nothing else today").crayonType(.body).foregroundStyle(CrayonColor.softText)
            }
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                if index == 0 {
                    rowView(row, picture: 104, title: .head, detail: "\(TimeText.clock(row.start)) – \(TimeText.clock(row.end))")
                } else {
                    rowView(row, picture: 72, title: .body, detail: TimeText.clock(row.start))
                }
            }
        }
    }

    private func dayOffBlock(_ day: HomeFeature.KidDay) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            kidHeader(day.kid)
            if let today = store.today {
                Text(DayText.name(today.weekday(Calendar.current))).crayonType(.body)
                    .foregroundStyle(CrayonColor.softText)
            }
            Text("No school, no bus").crayonType(.title).foregroundStyle(CrayonColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let item = HomeModel.nextItem(day.slots, minute: store.minute) {
                rowView(item, picture: 72, title: .body,
                        detail: "\(TimeText.clock(item.start)) – \(TimeText.clock(item.end))")
            }
        }
    }

    private func kidBBlock(_ day: HomeFeature.KidDay) -> some View {
        let now = DayPlanner.now(at: store.minute, in: day.slots)
        return VStack(alignment: .leading, spacing: Spacing.m) {
            kidHeader(day.kid)
            KidNowNext(now: now.current?.iconName ?? "actPlay", next: now.next?.iconName)
        }
    }

    private func rowView(_ row: NextRow, picture: CGFloat, title: CrayonType, detail: String) -> some View {
        HStack(spacing: 20) {
            KitIcon(KitSlot(rawValue: row.iconName) ?? .actPlay, size: picture)
            VStack(alignment: .leading, spacing: 4) {
                Text(row.title).crayonType(title).foregroundStyle(CrayonColor.ink).lineLimit(1)
                Text(detail).crayonType(title == .head ? .body : .caption).foregroundStyle(CrayonColor.softText)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
