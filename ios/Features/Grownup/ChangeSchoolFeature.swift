import ComposableArchitecture
import Domain
import Foundation
import Localization
import ScheduleStore
import SchoolDirectory
import Strings

/// G7 · Change school (spec "Where the kid goes changes"): search the school list (as on S2), pick
/// one, choose when it starts ("Next term" or a date), Save. Until that day the kid keeps the old
/// school and Settings shows the pending change, which can be changed or cancelled; from that day the
/// new school is the kid's school and the weekday template uses its hours. After Save, Our buses
/// opens for the new trip.
@Reducer
public struct ChangeSchoolFeature {
    public enum StartsOn: Hashable, Sendable { case nextTerm, date }
    /// S2's "Goes to" (design session 2026-11-15: G7 reuses S2's top rows).
    public enum Place: Hashable, Sendable { case school, preschool, home }

    @ObservableState
    public struct State: Equatable {
        public var kid: Kid.ID
        public var today: Day
        public var calendar: Calendar
        /// Every word this screen shows comes from here (views hold no values).
        public var strings = Localizer.injected
        /// Nothing about the kid's school is known before the store answers: no form until then.
        public var phase: Phase = .loading

        /// The place picked when the form opens, when it is not the kid's place now (G1's School
        /// "Remove" opens on "At home").
        public var opensAt: Place?

        public init(kid: Kid.ID, today: Day, calendar: Calendar, opensAt: Place? = nil) {
            self.kid = kid
            self.today = today
            self.calendar = calendar
            self.opensAt = opensAt
        }

        public var title: String { strings.tr("change_school.title") }
        public var loadFailedText: String { strings.tr("change_school.load_failed") }
        /// The keyboard goes down while the "Starts on" card is open.
        public var hidesKeyboard: Bool {
            guard case let .ready(form) = phase else { return false }
            return form.isShowingStartsOn
        }

        /// Runs `body` on the form; actions that arrive before it is ready do nothing.
        mutating func updateForm(_ body: (inout Form) -> Effect<Action>) -> Effect<Action> {
            guard case var .ready(form) = phase else { return .none }
            let effect = body(&form)
            phase = .ready(form)
            return effect
        }
    }

    /// The screen before the store answers, with the kid's school and year, or when the kid is gone.
    @CasePathable @dynamicMemberLookup
    public enum Phase: Equatable {
        case loading
        case ready(Form)
        case failed
    }

    /// Everything G7 shows once the kid, their routines, the school list and the year are known.
    public struct Form: Equatable {
        public var stored: Kid
        public var routines: [Routine]
        public var directory: [SchoolEntry]
        public var schoolYear: SchoolCalendar
        /// The picked school's own year (board G7: Next term is the new school's next term); nil
        /// until it loads, when the kid's year stands in.
        public var pickedYear: SchoolCalendar?
        public var text = ""
        public var matches: [SchoolEntry] = []
        public var picked: SchoolEntry?
        public var startsOn: StartsOn
        /// The "Goes to" tab: the kid's place now until a grown-up taps another.
        public var place: Place
        /// Preschool: the typed name, drop-off and pick-up (minutes after midnight).
        public var preschoolName = ""
        /// They start on the S2 defaults, which count as answers (user, 2026-11-18).
        public var dropOff = School.defaultStart
        public var pickUp = School.defaultEnd
        /// The "Starts on" card is open (after a school pick, Preschool's Save, or At home).
        public var isCardOpen = false
        public var date: Day
        public var today: Day
        public var calendar: Calendar
        public var strings: Localizer
        public var isConfirmingCancel = false
        public var saveError: String?

        /// Built in `.loaded`, with the kid's place picked and "Starts on" on Next term when the
        /// year has one (else Date).
        public init(stored: Kid, routines: [Routine], directory: [SchoolEntry], schoolYear: SchoolCalendar,
                    today: Day, calendar: Calendar, strings: Localizer) {
            self.stored = stored
            self.routines = routines
            self.directory = directory
            self.schoolYear = schoolYear
            self.today = today
            date = today
            self.calendar = calendar
            self.strings = strings
            place = Self.place(of: stored)
            startsOn = .nextTerm
            if nextTermStart == nil { startsOn = .date }
        }

        static func place(of kid: Kid) -> Place {
            guard let school = kid.school else { return .home }
            return school.isPreschool ? .preschool : .school
        }

        private var homeName: String { strings.tr("settings.child.home") }
        public var currentName: String { stored.school?.name ?? homeName }
        /// "From 5 Jan → Example Primary School" while a change waits for its day.
        public var pendingLine: String? {
            guard let pending = stored.pendingSchool else { return nil }
            return strings.tr("change_school.pending", DayText.dayMonth(pending.from, calendar: calendar),
                              pending.school?.name ?? homeName)
        }

        /// The kid's place now (the tab picked when the screen opens).
        public var currentPlace: Place { Self.place(of: stored) }
        public var placeTabs: [(Place, String)] {
            [(.school, strings.tr("s2.goes.school")), (.preschool, strings.tr("s2.goes.preschool")),
             (.home, strings.tr("s2.goes.home"))]
        }
        /// Preschool's rows show "Save", which opens the card once the name and both times are in.
        public var canContinuePreschool: Bool {
            guard place == .preschool else { return false }
            return !preschoolName.trimmingCharacters(in: .whitespaces).isEmpty && dropOff < pickUp
        }
        /// A time as the field prints it.
        public func timeLabel(_ minute: Int) -> String { TimeText.withPeriod(minute) }
        public func timeDate(_ minute: Int) -> Date {
            Day(year: 2026, month: 1, day: 1).date(minute: minute, calendar: calendar)
        }

        /// The new place: the picked school, the typed preschool, or nil for at home.
        public var newSchool: School? {
            switch place {
            case .school: return picked.map(School.init(entry:))
            case .preschool:
                guard canContinuePreschool else { return nil }
                return School(name: preschoolName.trimmingCharacters(in: .whitespaces), days: Weekday.schoolDays,
                              start: dropOff, end: pickUp, arriveBy: dropOff, kind: .preschool)
            case .home: return nil
            }
        }
        /// The card's title: the new place's name, or "At home".
        public var cardTitle: String { newSchool?.name ?? homeName }
        /// The year Next term counts in: the picked school's once it loads, else the kid's.
        var year: SchoolCalendar { pickedYear ?? schoolYear }
        /// The first day of the next term, if it is known.
        public var nextTermStart: Day? {
            year.terms.filter { $0.start > today }.map(\.start).min()
        }
        /// The day the new school starts.
        public var startDay: Day {
            switch startsOn {
            case .nextTerm: nextTermStart ?? date
            case .date: max(date, today)
            }
        }
        public var startLabel: String { DayText.dayMonth(startDay, calendar: calendar) }
        /// Board G7: the "Starts on" card opens once a school is picked.
        public var isShowingStartsOn: Bool { isCardOpen }
        public var startsOnTabs: [(StartsOn, String)] {
            [(.nextTerm, strings.tr("change_school.next_term")), (.date, strings.tr("change_school.date"))]
        }
        /// Board G7: "Mon 4 Jan · Term 1" under Next term; nothing under Date (the date field says it).
        public var startsOnCaption: String? {
            guard startsOn == .nextTerm, let start = nextTermStart,
                  let term = year.terms.first(where: { $0.start == start }) else { return nil }
            return strings.tr("change_school.next_term.caption", DayText.short(start, calendar: calendar), term.name)
        }
        public var dateValue: Date { max(date, today).date(calendar: calendar) }
        public var canSave: Bool {
            switch place {
            case .school: return picked != nil
            case .preschool: return canContinuePreschool
            case .home: return currentPlace != .home || stored.pendingSchool != nil
            }
        }
        public var cancelTitle: String { strings.tr("change_school.cancel.title", currentName) }

        // MARK: Words the view shows

        public var saveTitle: String { strings.tr("change_school.save") }
        public var cardCancelTitle: String { strings.tr("from_when.cancel") }
        public var keepTitle: String { strings.tr("change_school.cancel.keep") }
        public var stayTitle: String { strings.tr("change_school.cancel.stay") }
        public var cancelChangeTitle: String { strings.tr("change_school.cancel") }
        public var goesToLabel: String { strings.tr("s2.goes") }
        public var schoolLabel: String { strings.tr("s2.school") }
        public var schoolPlaceholder: String { strings.tr("s2.school.placeholder") }
        public var preschoolLabel: String { strings.tr("s2.preschool") }
        public var preschoolPlaceholder: String { strings.tr("s2.preschool.placeholder") }
        public var preschoolHint: String { strings.tr("s2.preschool.hint") }
        public var hoursLabel: String { strings.tr("s2.hours") }

        /// The kid with the change, and the weekday template from its first day on the new hours.
        var change: (kid: Kid, routine: Routine?)? {
            guard canSave else { return nil }
            var kid = stored
            let school = newSchool
            let day = startDay
            if day <= today {
                kid.school = school
                kid.pendingSchool = nil
            } else {
                kid.pendingSchool = PendingSchool(school: school, from: day)
            }
            // The old school's waiting hours from the move's day on would never come (they wrote no
            // template, so nothing else goes).
            if let waiting = kid.pendingHours, waiting.from >= day { kid.pendingHours = nil }
            let first = (0..<7).map { day.adding(days: $0, calendar: calendar) }
                .first { $0.weekday(calendar) != .saturday && $0.weekday(calendar) != .sunday } ?? day
            let routine = DayPlanner.template(for: kid.id, on: first, routines: routines, holidays: [], calendar: calendar)
                .map { Routine(kid: kid.id, dayType: .weekday, from: day, blocks: TemplateEdit.placingSchool($0.blocks, school: school)) }
            return (kid, routine)
        }

        /// "Cancel the change": the template from the pending day goes back to the old school's hours.
        var cancel: (kid: Kid, routine: Routine?)? {
            var kid = stored
            guard let pending = kid.pendingSchool else { return nil }
            kid.pendingSchool = nil
            let routine = DayPlanner.template(for: kid.id, on: pending.from, routines: routines, holidays: [], calendar: calendar)
                .map { Routine(kid: kid.id, dayType: .weekday, from: pending.from,
                               blocks: TemplateEdit.placingSchool($0.blocks, school: kid.school)) }
            return (kid, routine)
        }
    }

    public enum Action: Equatable {
        case task
        case loaded(ScheduleSnapshot?, directory: [SchoolEntry], year: SchoolCalendar)
        case textChanged(String)
        case picked(SchoolEntry)
        case placeTapped(Place)
        case preschoolNameChanged(String)
        case dropOffPicked(Date)
        case pickUpPicked(Date)
        case preschoolSaveTapped
        case startsOnTapped(StartsOn)
        /// The G7 card's Cancel: no school picked, back to the search.
        case cardCancelled
        case pickedYearLoaded(SchoolCalendar)
        case datePicked(Date)
        case saveTapped
        case saved(Bool)
        /// "Cancel the change": asks once ("Stay at {old school}?"), then removes the pending change.
        case cancelChangeTapped
        case cancelConfirmed
        case cancelKept
        case backTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case finished
            /// After Save, Our buses opens for the new trip (spec: S3 for the new place).
            case openBuses(Kid.ID)
        }
    }

    @Dependency(\.scheduleStore) var scheduleStore
    @Dependency(\.schoolDirectory) var schoolDirectory

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                let kid = state.kid
                return .run { [scheduleStore, schoolDirectory] send in
                    let snapshot = try? await scheduleStore.load()
                    let directory = await schoolDirectory.schools()
                    let family = await schoolDirectory.family(kids: snapshot?.kids ?? [], publicHolidays: [])
                    await send(.loaded(snapshot, directory: directory, year: family.schools[kid] ?? .none))
                }

            case let .loaded(snapshot, directory, year):
                guard let snapshot, let kid = snapshot.kids.first(where: { $0.id == state.kid }) else {
                    state.phase = .failed
                    return .none
                }
                state.phase = .ready(Form(stored: kid, routines: snapshot.routines, directory: directory,
                                          schoolYear: year, today: state.today, calendar: state.calendar,
                                          strings: state.strings))
                // Picked as a tap would pick it (At home goes straight to "Starts on").
                guard let place = state.opensAt, place != Form.place(of: kid) else { return .none }
                return state.updateForm { reduce(&$0, .placeTapped(place)) }

            case .backTapped:
                return .send(.delegate(.finished))

            case .delegate:
                return .none

            default:
                return state.updateForm { form in reduce(&form, action) }
            }
        }
    }

    /// The form's actions (after load).
    private func reduce(_ form: inout Form, _ action: Action) -> Effect<Action> {
        switch action {
        case let .textChanged(text):
            // The field sends its text again when it loses focus (the G7 card hides the keyboard):
            // the same text keeps the pick.
            guard text != form.text else { return .none }
            form.text = text
            form.picked = nil
            form.matches = SchoolSearch.matches(text, in: form.directory)
            return .none

        case let .picked(entry):
            form.picked = entry
            form.pickedYear = nil
            form.text = entry.name
            form.matches = []
            form.isCardOpen = true
            let age = form.stored.age ?? 7
            return .run { [schoolDirectory] send in
                await send(.pickedYearLoaded(await schoolDirectory.calendar(School(entry: entry), age)))
            }

        case let .pickedYearLoaded(year):
            form.pickedYear = year
            form.startsOn = form.nextTermStart == nil ? .date : .nextTerm
            return .none

        case let .placeTapped(place):
            form.place = place
            form.picked = nil
            form.pickedYear = nil
            form.text = ""
            form.matches = []
            // Design session 2026-11-15: At home goes straight to the "Starts on" card.
            if place == .home, form.canSave { form.isCardOpen = true }
            return .none

        case let .preschoolNameChanged(name):
            guard name != form.preschoolName else { return .none }
            form.preschoolName = name
            return .none

        case let .dropOffPicked(date):
            form.dropOff = Day.minute(of: date, calendar: form.calendar)
            return .none

        case let .pickUpPicked(date):
            form.pickUp = Day.minute(of: date, calendar: form.calendar)
            return .none

        case .preschoolSaveTapped:
            guard form.canContinuePreschool else { return .none }
            form.isCardOpen = true
            return .none

        case .cardCancelled:
            form.isCardOpen = false
            guard form.place == .school else { return .none }
            form.picked = nil
            form.pickedYear = nil
            form.text = ""
            form.matches = []
            return .none

        case let .startsOnTapped(choice):
            form.startsOn = choice
            return .none

        case let .datePicked(date):
            form.startsOn = .date
            form.date = max(Day(date, calendar: form.calendar), form.today)
            return .none

        case .saveTapped:
            guard let change = form.change else { return .none }
            return .run { [scheduleStore] send in
                do {
                    try await scheduleStore.saveKid(change.kid)
                    if let routine = change.routine { try await scheduleStore.saveRoutine(routine) }
                    await send(.saved(true))
                } catch {
                    await send(.saved(false))
                }
            }

        case let .saved(ok):
            guard ok else {
                form.saveError = form.strings.tr("day.save_failed")
                return .none
            }
            form.isCardOpen = false
            // A kid at home has no trip: back to G4 instead of the new trip's screen.
            return .send(.delegate(form.place == .home ? .finished : .openBuses(form.stored.id)))

        case .cancelChangeTapped:
            form.isConfirmingCancel = true
            return .none

        case .cancelKept:
            form.isConfirmingCancel = false
            return .none

        case .cancelConfirmed:
            form.isConfirmingCancel = false
            guard let cancel = form.cancel else { return .none }
            form.stored = cancel.kid
            return .run { [scheduleStore] _ in
                try? await scheduleStore.saveKid(cancel.kid)
                if let routine = cancel.routine { try? await scheduleStore.saveRoutine(routine) }
            }

        case .task, .loaded, .backTapped, .delegate:
            return .none
        }
    }
}
