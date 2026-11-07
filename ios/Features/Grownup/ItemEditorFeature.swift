import ComposableArchitecture
import Domain
import Foundation
import HolidayProvider
import ScheduleStore

/// Add to the day (boards C3, C4, C3k) and edit an item (C4 edit mode, E5).
@Reducer
public struct ItemEditorFeature {
    public enum Mode: Equatable, Sendable {
        case add(Audience)
        case editOnce(ScheduleItem)
        case editWeekly(ScheduleItem)
    }

    public enum Confirm: Equatable, Sendable {
        case leave, removeOnce, removeSeries
    }

    @ObservableState
    public struct State: Equatable {
        public var mode: Mode
        public var form: ItemForm
        public var original: ItemForm
        public var calendar: Calendar
        public var today: Day
        public var nowMinute: Int
        public var snapshot: ScheduleSnapshot?
        public var holidays: Set<Day> = []
        /// Weeks forward in the just-once date chips; never before this week.
        public var datePage = 0
        public var confirm: Confirm?
        public var saveError: String?

        public init(mode: Mode, repeats: ItemForm.Repeat = .weekly, now: Date, calendar: Calendar) {
            self.mode = mode
            self.calendar = calendar
            today = Day(now, calendar: calendar)
            let parts = calendar.dateComponents([.hour, .minute], from: now)
            nowMinute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            let initial: ItemForm
            switch mode {
            case let .add(audience):
                var form = ItemForm.defaults(audience: audience, now: now, calendar: calendar)
                form.repeats = repeats
                initial = form
            case let .editOnce(item), let .editWeekly(item):
                initial = ItemForm(item: item)
            }
            form = initial
            original = initial
        }

        public var isAdding: Bool { if case .add = mode { true } else { false } }

        public var editingItem: ScheduleItem? {
            switch mode {
            case .add: nil
            case let .editOnce(item), let .editWeekly(item): item
            }
        }

        public var title: String { isAdding ? "Add to the day" : "Edit \(original.name)" }
        public var primaryTitle: String { isAdding ? "Add to the clock" : "Save changes" }
        public var problem: FormProblem? { form.problem(today: today, nowMinute: nowMinute) }
        public var hasChanges: Bool { form != original }

        /// Five dates from today, a week per page (board C4).
        public var visibleDates: [Day] {
            (0..<5).map { today.adding(days: datePage * 7 + $0, calendar: calendar) }
        }

        public var overlapCaption: String? {
            guard let snapshot else { return nil }
            return form.overlapCaption(items: snapshot.items, kids: snapshot.kids, holidays: holidays,
                                       editing: editingItem?.id, calendar: calendar)
        }

        public var confirmTitle: String? {
            switch confirm {
            case .leave: isAdding ? "Leave without adding?" : "Leave without saving?"
            case .removeOnce: "Remove \(original.name)?"
            case .removeSeries: "Remove \(original.name) every week?"
            case nil: nil
            }
        }

        public var confirmMessage: String? {
            switch confirm {
            case .removeOnce: "It leaves the clock on \(DayText.long(original.date, calendar: calendar))."
            default: nil
            }
        }
    }

    public enum Action: BindableAction, Equatable {
        case task
        case loaded(ScheduleSnapshot?, holidays: [Holiday])
        case binding(BindingAction<State>)
        case picturePicked(String)
        case repeatChanged(ItemForm.Repeat)
        case dateTapped(Day)
        case datePageTapped(Int)
        case saveTapped
        case saved(Bool)
        case backTapped
        case removeTapped
        case confirmAccepted
        case confirmCancelled
        case removed
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            /// Saved, removed or left: the app pops this screen.
            case finished
        }
    }

    @Dependency(\.scheduleStore) var scheduleStore
    @Dependency(\.holidays) var holidays
    @Dependency(\.uuid) var uuid

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .task:
                let year = state.today.year
                return .run { [scheduleStore, holidays] send in
                    let snapshot = try? await scheduleStore.load()
                    await send(.loaded(snapshot, holidays: await holidays.holidays(year)))
                }

            case let .loaded(snapshot, holidays):
                state.snapshot = snapshot
                state.holidays = Set(holidays.map(\.day))
                return .none

            case .binding:
                state.saveError = nil
                return .none

            case let .picturePicked(name):
                state.form.pickPicture(name)
                return .none

            case let .repeatChanged(repeats):
                // An every-week item cannot turn into a one-off here (board E5).
                if case .editWeekly = state.mode { return .none }
                state.form.repeats = repeats
                return .none

            case let .dateTapped(day):
                state.form.date = day
                return .none

            case let .datePageTapped(step):
                state.datePage = max(0, state.datePage + step)
                return .none

            case .saveTapped:
                guard state.problem == nil else { return .none }
                state.saveError = nil
                let id = state.editingItem?.id ?? uuid()
                var item = state.form.item(id: id, today: state.today)
                if case let .editWeekly(original) = state.mode, case let .weekly(_, from, until) = original.recurrence,
                   case let .weekly(days, _, _) = item.recurrence {
                    item.recurrence = .weekly(days, from: from, until: until)
                    item.skippedDays = original.skippedDays
                }
                return .run { [scheduleStore, item] send in
                    do {
                        try await scheduleStore.save(item)
                        await send(.saved(true))
                    } catch {
                        await send(.saved(false))
                    }
                }

            case .saved(true):
                return .send(.delegate(.finished))

            case .saved(false):
                state.saveError = "Couldn't save. Try again."
                return .none

            case .backTapped:
                guard state.hasChanges else { return .send(.delegate(.finished)) }
                state.confirm = .leave
                return .none

            case .removeTapped:
                state.confirm = .removeOnce
                return .none

            case .confirmCancelled:
                state.confirm = nil
                return .none

            case .confirmAccepted:
                let confirm = state.confirm
                state.confirm = nil
                switch confirm {
                case .leave:
                    return .send(.delegate(.finished))
                case .removeOnce:
                    guard let id = state.editingItem?.id else { return .none }
                    return .run { [scheduleStore] send in
                        try? await scheduleStore.delete(id)
                        await send(.removed)
                    }
                case .removeSeries, nil:
                    return .none
                }

            case .removed:
                return .send(.delegate(.finished))

            case .delegate:
                return .none
            }
        }
    }
}
