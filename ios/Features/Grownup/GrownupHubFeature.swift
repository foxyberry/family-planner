import ComposableArchitecture
import Domain
import Foundation
import ScheduleStore

/// Our kids (boards C1 and E6): one tab per kid, their day and school, and their schedule items.
@Reducer
public struct GrownupHubFeature {
    @ObservableState
    public struct State: Equatable {
        public var selectedKid: Kid.ID?
        public var snapshot: ScheduleSnapshot?
        public var today: Day?
        public var nowMinute = 0
        /// Replaced by the `\.calendar` dependency on `.task`, together with `today`.
        public var calendar = Calendar(identifier: .gregorian)

        public init() {}

        public var kid: Kid? { snapshot?.kids.first { $0.id == selectedKid } }

        public var sections: [HubSection] {
            guard let kid, let snapshot else { return [] }
            return HubModel.sections(kid: kid, routines: snapshot.routines, missions: snapshot.missions)
        }

        public var weeklyHeading: String { kid.map(HubModel.weeklyHeading) ?? "" }

        public var weeklyRows: [HubItemRow] {
            guard let kid, let snapshot else { return [] }
            return HubModel.weeklyRows(kid: kid, items: snapshot.items)
        }

        /// Empty until `.task` knows today.
        public var onceRows: [HubItemRow] {
            guard let kid, let snapshot, let today else { return [] }
            return HubModel.onceRows(kid: kid, items: snapshot.items, routines: snapshot.routines, today: today,
                                     nowMinute: nowMinute, calendar: calendar)
        }
    }

    public enum Action: Equatable {
        case task
        case loaded(ScheduleSnapshot?)
        case kidTabTapped(Kid.ID)
        /// Navigation the app's stack handles.
        case weeklyItemTapped(ScheduleItem.ID)
        case onceItemTapped(ScheduleItem.ID)
        case dayRowTapped
        case missionsRowTapped
        case addWeeklyTapped
        case addOnceTapped
        case backTapped
        case galleryButtonTapped
    }

    @Dependency(\.calendar) var calendar
    @Dependency(\.date) var date
    @Dependency(\.scheduleStore) var scheduleStore

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let now = date.now
                state.calendar = calendar
                state.today = Day(now, calendar: calendar)
                state.nowMinute = Day.minute(of: now, calendar: calendar)
                return .run { [scheduleStore] send in
                    await send(.loaded(try? await scheduleStore.load()))
                }

            case let .loaded(snapshot):
                state.snapshot = snapshot
                if state.selectedKid == nil || !(snapshot?.kids.contains { $0.id == state.selectedKid } ?? false) {
                    state.selectedKid = snapshot?.kids.first?.id
                }
                return .none

            case let .kidTabTapped(id):
                state.selectedKid = id
                return .none

            case .weeklyItemTapped, .onceItemTapped, .addWeeklyTapped, .addOnceTapped, .backTapped, .dayRowTapped, .missionsRowTapped,
                 .galleryButtonTapped:
                return .none
            }
        }
    }
}
