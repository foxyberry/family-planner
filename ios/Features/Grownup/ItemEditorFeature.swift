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
        /// The every-week item as saved right now (skips are saved at once, board E5).
        public var weeklyItem: ScheduleItem?
        /// The date "Skip just …" skipped, while it can still be undone.
        public var skippedDay: Day?

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
            if case let .editWeekly(item) = mode { weeklyItem = item }
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
            case .removeOnce:
                return "It leaves the clock on \(DayText.long(original.date, calendar: calendar))."
            case .removeSeries:
                let from = DayText.short(skipCandidate ?? today, calendar: calendar)
                return "It leaves \(clockOwner) from \(from). Days before stay in the diary."
            default:
                return nil
            }
        }

        /// "Kid A's clock", or "both kids' clocks".
        private var clockOwner: String {
            switch form.audience {
            case let .kid(id): "\(snapshot?.kids.first { $0.id == id }?.name ?? "the")'s clock"
            case .both: "both kids' clocks"
            }
        }

        /// The next date of the series that has not ended yet (board E5 "Skip just …").
        public var skipCandidate: Day? {
            weeklyItem.flatMap {
                SeriesEdits.nextOccurrence(of: $0, from: today, nowMinute: nowMinute, holidays: holidays,
                                           calendar: calendar)
            }
        }

        public var skipRowTitle: String? {
            if let skippedDay { return "Skipped \(DayText.short(skippedDay, calendar: calendar)) · Undo" }
            return skipCandidate.map { "Skip just \(DayText.short($0, calendar: calendar))" }
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
        case skipNextTapped
        case undoSkipTapped
        case skipSaved(ScheduleItem, skipped: Day?)
        case removeSeriesTapped
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
                var items = [item]
                if let weekly = state.weeklyItem, case let .weekly(_, from, until) = weekly.recurrence,
                   case let .weekly(days, _, _) = item.recurrence {
                    // Changes start from the next time; a run that already started today keeps its times.
                    item.recurrence = .weekly(days, from: from, until: until)
                    item.skippedDays = weekly.skippedDays
                    items = SeriesEdits.applying(edit: item, to: weekly, today: state.today, nowMinute: state.nowMinute,
                                                 newID: uuid(), holidays: state.holidays, calendar: state.calendar)
                }
                return .run { [scheduleStore, items] send in
                    do {
                        if items.count == 1 { try await scheduleStore.save(items[0]) } else {
                            try await scheduleStore.saveAll(items)
                        }
                        await send(.saved(true))
                    } catch {
                        await send(.saved(false))
                    }
                }

            case .skipNextTapped:
                guard let weekly = state.weeklyItem, let day = state.skipCandidate else { return .none }
                return save(SeriesEdits.skipping(weekly, day: day), skipped: day)

            case .undoSkipTapped:
                guard let weekly = state.weeklyItem, let day = state.skippedDay else { return .none }
                return save(SeriesEdits.unskipping(weekly, day: day), skipped: nil)

            case let .skipSaved(item, skipped):
                state.weeklyItem = item
                state.skippedDay = skipped
                return .none

            case .removeSeriesTapped:
                state.confirm = .removeSeries
                return .none

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
                case .removeSeries:
                    guard let weekly = state.weeklyItem else { return .none }
                    let ended = SeriesEdits.ending(weekly, before: state.skipCandidate ?? state.today,
                                                   calendar: state.calendar)
                    return .run { [scheduleStore] send in
                        do {
                            try await scheduleStore.save(ended)
                            await send(.saved(true))
                        } catch {
                            await send(.saved(false))
                        }
                    }
                case nil:
                    return .none
                }

            case .removed:
                return .send(.delegate(.finished))

            case .delegate:
                return .none
            }
        }
    }

    /// Skips are saved at once, without "Save changes" (board E5).
    private func save(_ item: ScheduleItem, skipped: Day?) -> Effect<Action> {
        .run { [scheduleStore] send in
            do {
                try await scheduleStore.save(item)
                await send(.skipSaved(item, skipped: skipped))
            } catch {
                await send(.saved(false))
            }
        }
    }
}
