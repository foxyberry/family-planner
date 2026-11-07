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

        public init() {}

        public var kid: Kid? { snapshot?.kids.first { $0.id == selectedKid } }
    }

    public enum Action: Equatable {
        case task
        case loaded(ScheduleSnapshot?)
        case kidTabTapped(Kid.ID)
        /// Navigation the app's stack handles.
        case weeklyItemTapped(ScheduleItem.ID)
        case onceItemTapped(ScheduleItem.ID)
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
                state.today = Day(now, calendar: calendar)
                let parts = calendar.dateComponents([.hour, .minute], from: now)
                state.nowMinute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
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

            case .weeklyItemTapped, .onceItemTapped, .addWeeklyTapped, .addOnceTapped, .backTapped,
                 .galleryButtonTapped:
                return .none
            }
        }
    }
}
