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

    /// One tab under "For": a kid, or both kids.
    public struct AudienceTab: Equatable, Sendable {
        public var audience: Audience
        public var title: String
        /// The kid's colour; nil for "Both".
        public var colorIndex: Int?

        public init(audience: Audience, title: String, colorIndex: Int?) {
            self.audience = audience
            self.title = title
            self.colorIndex = colorIndex
        }
    }

    /// One date chip in the just-once row.
    public struct DateOption: Equatable, Sendable {
        public var day: Day
        /// "Mon"
        public var weekday: String
        public var isOn: Bool

        public init(day: Day, weekday: String, isOn: Bool) {
            self.day = day
            self.weekday = weekday
            self.isOn = isOn
        }
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
        /// A save, skip or remove is on its way to the store; further taps wait for it.
        public var isSaving = false
        /// The every-week item as saved right now (skips are saved at once, board E5).
        public var weeklyItem: ScheduleItem?
        /// The date "Skip just …" skipped, while it can still be undone.
        public var skippedDay: Day?
        /// The id a new item has in the preview, kept from `.task` on (save still asks for a fresh id).
        public var draftID: ScheduleItem.ID?

        public init(mode: Mode, repeats: ItemForm.Repeat = .weekly, now: Date, calendar: Calendar) {
            self.mode = mode
            self.calendar = calendar
            today = Day(now, calendar: calendar)
            nowMinute = Day.minute(of: now, calendar: calendar)
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
        public var isEditingWeekly: Bool { if case .editWeekly = mode { true } else { false } }

        public var editingItem: ScheduleItem? {
            switch mode {
            case .add: nil
            case let .editOnce(item), let .editWeekly(item): item
            }
        }

        public var title: String { isAdding ? "Add to the day" : "Edit \(original.name)" }
        public var primaryTitle: String { isAdding ? "Add to the clock" : "Save changes" }
        /// While editing, an event that already started keeps its start time without "That time has passed".
        public var problem: FormProblem? {
            let keptStart = !isAdding && form.date == original.date ? original.start : nil
            return form.problem(today: today, nowMinute: nowMinute, keptStart: keptStart)
        }
        /// The problem shown under `row`, if the form's first problem belongs there.
        public func problem(for row: FormRow) -> FormProblem? {
            problem.flatMap { $0.row == row ? $0 : nil }
        }
        public var canSave: Bool { problem == nil && !isSaving }
        public var hasChanges: Bool { form != original }

        /// A tab per kid, and "Both" once there are two or more kids.
        public var audienceTabs: [AudienceTab] {
            let kids = snapshot?.kids ?? []
            return kids.map { AudienceTab(audience: .kid($0.id), title: $0.name, colorIndex: $0.colorIndex) }
                + (kids.count > 1 ? [AudienceTab(audience: .both, title: "Both", colorIndex: nil)] : [])
        }

        /// The form's times as times on today, for the time fields.
        public var startTime: Date { today.date(minute: form.start, calendar: calendar) }
        public var endTime: Date { today.date(minute: form.end, calendar: calendar) }

        /// Five dates from today, a week per page (board C4).
        public var visibleDates: [Day] {
            (0..<5).map { today.adding(days: datePage * 7 + $0, calendar: calendar) }
        }

        public var dateChips: [DateOption] {
            visibleDates.map {
                DateOption(day: $0, weekday: DayText.shortName($0.weekday(calendar)), isOn: form.date == $0)
            }
        }

        /// Paging never goes before this week.
        public var canPageEarlier: Bool { datePage > 0 }

        /// The every-week side column's title (board E5): "Every Mon and Wed".
        public var everyTitle: String { DayText.every(form.days) }

        /// The add and just-once side column; the every-week side column has none.
        public var preview: FormPreview? {
            guard !isEditingWeekly else { return nil }
            return form.preview(kids: snapshot?.kids ?? [], routines: snapshot?.routines ?? [],
                                items: snapshot?.items ?? [], holidays: holidays,
                                draftID: editingItem?.id ?? draftID, showsDraft: problem == nil, today: today,
                                calendar: calendar)
        }

        public var overlapCaption: String? {
            guard let snapshot else { return nil }
            return form.overlapCaption(items: snapshot.items, kids: snapshot.kids, holidays: holidays,
                                       editing: editingItem?.id, today: today, calendar: calendar)
        }

        public var confirmTitle: String? {
            switch confirm {
            case .leave: isAdding ? "Leave without adding?" : "Leave without saving?"
            case .removeOnce: "Remove \(original.name)?"
            case .removeSeries: "Remove \(original.name) every week?"
            case nil: nil
            }
        }

        public var confirmCancelTitle: String { confirm == .leave ? "Keep editing" : "Keep" }
        public var confirmAcceptTitle: String { confirm == .leave ? "Leave" : "Remove" }
        public var confirmIsDestructive: Bool { confirm != .leave }

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

        /// The skip row undoes the skip it just saved.
        public var skipRowIsUndo: Bool { skippedDay != nil }
    }

    public enum Action: BindableAction, Equatable {
        case task
        case loaded(ScheduleSnapshot?, holidays: [Holiday])
        case binding(BindingAction<State>)
        case audienceTapped(Audience)
        case picturePicked(String)
        case startPicked(Date)
        case endPicked(Date)
        case dayToggled(Weekday)
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
        /// "Skip just …", or "Skipped … · Undo" once skipped.
        case skipRowTapped
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
                if state.isAdding, state.draftID == nil { state.draftID = uuid() }
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

            case let .audienceTapped(audience):
                state.saveError = nil
                state.form.audience = audience
                return .none

            case let .picturePicked(name):
                state.form.pickPicture(name)
                return .none

            case let .startPicked(time):
                state.saveError = nil
                state.form.start = Day.minute(of: time, calendar: state.calendar)
                return .none

            case let .endPicked(time):
                state.saveError = nil
                state.form.end = Day.minute(of: time, calendar: state.calendar)
                return .none

            case let .dayToggled(day):
                state.saveError = nil
                if state.form.days.contains(day) { state.form.days.remove(day) } else { state.form.days.insert(day) }
                return .none

            case let .repeatChanged(repeats):
                // An every-week item cannot turn into a one-off here (board E5).
                if state.isEditingWeekly { return .none }
                state.form.repeats = repeats
                return .none

            case let .dateTapped(day):
                state.form.date = day
                return .none

            case let .datePageTapped(step):
                state.datePage = max(0, state.datePage + step)
                return .none

            case .saveTapped:
                guard state.canSave else { return .none }
                state.isSaving = true
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

            case .skipRowTapped:
                guard !state.isSaving, let weekly = state.weeklyItem else { return .none }
                if let day = state.skippedDay {
                    state.isSaving = true
                    return save(SeriesEdits.unskipping(weekly, day: day), skipped: nil)
                }
                guard let day = state.skipCandidate else { return .none }
                state.isSaving = true
                return save(SeriesEdits.skipping(weekly, day: day), skipped: day)

            case let .skipSaved(item, skipped):
                state.isSaving = false
                state.weeklyItem = item
                state.skippedDay = skipped
                return .none

            case .removeSeriesTapped:
                state.confirm = .removeSeries
                return .none

            case .saved(true):
                // Stays "saving": the screen is leaving, and a late second tap must not save again.
                return .send(.delegate(.finished))

            case .saved(false):
                state.isSaving = false
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
                if confirm != .leave {
                    guard !state.isSaving else { return .none }
                    state.isSaving = true
                }
                switch confirm {
                case .leave:
                    return .send(.delegate(.finished))
                case .removeOnce:
                    guard let id = state.editingItem?.id else { return .none }
                    return .run { [scheduleStore] send in
                        do {
                            try await scheduleStore.delete(id)
                            await send(.removed)
                        } catch {
                            await send(.saved(false))
                        }
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
