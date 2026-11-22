import ComposableArchitecture
import Domain
import Foundation
import HolidayProvider
import KitArt
import Localization
import ScheduleStore
import SchoolDirectory
import Strings

/// G4 · Edit School (spec "G4"): School's hours, days, Arrive by and Latest, Terms, how
/// the kid goes, Bring and the medal. **All days** asks G5 "Change from when?" (spec G5), then writes
/// the school record and a new weekday template from that day with School's slice on the new times
/// (as an All days save on the clock does). **This day** keeps the record and saves the day's own
/// template with School's slice moved (a late start, an early dismissal).
@Reducer
public struct SchoolEditorFeature {
    /// "This day" or "All days" (spec "Edit scope").
    public enum Scope: Hashable, Sendable { case thisDay, allDays }

    @ObservableState
    public struct State: Equatable {
        public var strings = Localizer.injected
        public var kid: Kid.ID
        /// The day G1 showed when "Details ›" opened G4; nil from the List or Settings (spec G5 "Which
        /// screens and days").
        public let shownDay: Day?
        /// The date "This day" changes: School's next day from the day G1 showed (that day when School
        /// is on it), else from today (today until School is over, then the next school day). Spec G5
        /// "More G5 edges": a carried day that has passed or has no School moves on.
        public var day: Day {
            let from = max(shownDay ?? today, today)
            return schoolDay(onOrAfter: from) ?? from
        }
        public var editScope: Scope = .allDays
        /// Board G5: the "Change from when?" card is open, with its choice and date.
        public var fromWhen: FromWhenTabs.Choice?
        public var fromWhenDate: Day
        /// The family's year: the kid's days off (school holidays, public holidays).
        public var family = FamilyCalendar()
        /// The school's year, for the Terms row (MOE calendar or its own dates).
        public var schoolYear: SchoolCalendar = .none
        /// The school list says whether this school follows MOE terms (a known MOE school, or one
        /// with its own term dates): then the Terms row is text only (spec G4 Terms, layout v63).
        public var termsKnown = false
        /// Board F2 over G4: the Bring card is open, and the bring list when it opened (Cancel puts it back).
        public var bringWas: [ItemMission]?
        public var isPickingMoreBring = false
        public var stored: Kid?
        public var school: School?
        public var original: School?
        public var routines: [Routine] = []
        /// The weekday template's School slice wins the medal (its trip's `medal`).
        public var medal = true
        public var originalMedal = true
        public var busPlan: BusPlan?
        public var today: Day
        /// The minute of the day now: today stops being School's next day once School is over.
        public var nowMinute: Int
        public var calendar: Calendar
        public var saveError: String?

        public init(kid: Kid.ID, today: Day, nowMinute: Int = 0, shownDay: Day? = nil, calendar: Calendar) {
            self.kid = kid
            self.today = today
            self.nowMinute = nowMinute
            self.shownDay = shownDay
            self.calendar = calendar
            fromWhenDate = today
        }

        /// The kid's days off.
        var daysOff: Set<Day> { family.daysOff(kid) }

        /// Whether School is on `day` for the saved school: one of its days, a school day (not a day
        /// off) and in the day's template (skipped or not, so a skip does not move This day).
        func hasSchool(on day: Day) -> Bool {
            guard let days = original?.days, days.contains(day.weekday(calendar)),
                  DayPlanner.dayType(on: day, holidays: daysOff, calendar: calendar) == .weekday else { return false }
            return DayPlanner.template(for: kid, on: day, routines: routines, holidays: daysOff, calendar: calendar)?
                .blocks.contains { $0.kind == .school } == true
        }

        /// The day carried from G1 as This day moved it (G5 opens on it, spec G5 #250); nil from the
        /// List or Settings, so G5 opens on Today.
        var carriedDay: Day? { shownDay == nil ? nil : day }

        /// The first day from `start` that has School (a year ahead at most); today counts only until
        /// School is over.
        func schoolDay(onOrAfter start: Day) -> Day? {
            (0..<366).lazy.map { start.adding(days: $0, calendar: self.calendar) }
                .filter { $0 != self.today || self.nowMinute < (self.original?.end ?? 0) }
                .first { self.hasSchool(on: $0) }
        }

        // MARK: G5 "Change from when?"

        /// Board G5's middle day: the first day after today, within 14 days, that School has with the
        /// changed days (a weekday of it that is not a day off).
        var nextDay: Day? {
            let days = school?.days ?? []
            return FromWhenTabs.nextDay(after: today, calendar: calendar) {
                days.contains($0.weekday(calendar))
                    && DayPlanner.dayType(on: $0, holidays: daysOff, calendar: calendar) == .weekday
            }
        }
        /// Board G5's tabs: "Today", School's next day ("Tomorrow" or "Wed 18 Nov"; none within 14
        /// days hides it), "Date".
        public var fromWhenTabs: [(FromWhenTabs.Choice, String)] {
            FromWhenTabs.tabs(next: nextDay, today: today, calendar: calendar)
        }
        public var fromWhenTitle: String { strings.tr("from_when.title") }
        public var fromWhenSave: String { strings.tr("from_when.save") }
        public var fromWhenCancel: String { strings.tr("from_when.cancel") }
        /// The tab the card shows; Today until it opens.
        public var fromWhenChoice: FromWhenTabs.Choice { fromWhen ?? .today }
        public var isAskingFromWhen: Bool { fromWhen != nil }
        /// Where the All days change starts: G5's choice, never before today.
        public var splitDay: Day {
            switch fromWhen {
            case .next?: nextDay ?? today
            case .date?: max(fromWhenDate, today)
            case .today?, nil: today
            }
        }
        public var fromWhenDateLabel: String { DayText.dayMonth(max(fromWhenDate, today), calendar: calendar) }
        public var fromWhenDateValue: Date { max(fromWhenDate, today).date(calendar: calendar) }

        /// Board G4 Terms: "MOE 2026 · Term 4 ends 20 Nov", or the school's own term end.
        public var termsText: String {
            SettingsModel.terms(schoolYear, today: today, dayCalendar: calendar) ?? L10n.tr("editor.row.nothing")
        }
        /// The S2 MOE switch shows only for a school our data does not know or one typed by hand
        /// (a known school's own dates are never overridden); a preschool shows it while it uses them.
        public var showsMoeCheck: Bool {
            guard let school, !termsKnown else { return false }
            return !school.isPreschool || school.usesMoeTerms == true
        }
        public var moeCheckText: String { strings.tr("s2.terms.moe") }
        public var usesMoeTerms: Bool { school?.usesMoeTerms ?? false }
        /// Board G4 Bring: "Library bag · Water bottle", or "Nothing".
        public var bring: [ItemMission] { school?.bring ?? [] }
        public var bringText: String? { bring.isEmpty ? nil : bring.map(\.name).joined(separator: " · ") }
        public var bringFirstPicture: String? { bring.first?.picture }
        public var bringPicked: Set<KitSlot> { Set(bring.compactMap { KitSlot(rawValue: $0.picture) }) }
        public var isBringOpen: Bool { bringWas != nil }
        public var bringSlots: [KitSlot] { isPickingMoreBring ? ItemEditorFeature.State.bringAll : ItemEditorFeature.State.bringGroup }

        public var title: String { L10n.tr("school_edit.title") }
        public var schoolName: String { school?.name ?? "" }
        /// "From 5 Jan: Example Primary School" while a G7 change waits for its day.
        public var pendingLine: String? {
            guard let pending = stored?.pendingSchool else { return nil }
            return L10n.tr("change_school.pending", DayText.dayMonth(pending.from, calendar: calendar),
                         pending.school?.name ?? L10n.tr("settings.child.home"))
        }
        /// Board G4's side line: "Every school day", or the days as chips.
        public var everyTitle: String { DayText.chips(school?.days ?? []) }
        /// Spec "E5 School rule": This day's side column as G3, "{Day d Mon} only" then "Skip this day".
        public var isThisDay: Bool { editScope == .thisDay }
        public var thisDayTitle: String { L10n.tr("editor.this_day.only", DayText.short(day, calendar: calendar)) }
        /// The day's template (its own one when it has it).
        var dayTemplate: Routine? {
            DayPlanner.template(for: kid, on: day, routines: routines, holidays: [], calendar: calendar)
        }
        /// School is skipped on this day (a sick day); "Bring back" undoes it.
        public var isDaySkipped: Bool { dayTemplate?.blocks.first { $0.kind == .school }?.isSkipped == true }
        public var canSkipDay: Bool { dayTemplate?.blocks.contains { $0.kind == .school } == true }
        public var skipTitle: String {
            isDaySkipped ? L10n.tr("editor.this_day.bring_back") : L10n.tr("editor.this_day.skip")
        }
        public var startDate: Date { today.date(minute: school?.start ?? 0, calendar: calendar) }
        public var endDate: Date { today.date(minute: school?.end ?? 0, calendar: calendar) }
        public var startLabel: String { TimeText.withPeriod(school?.start ?? 0) }
        public var endLabel: String { TimeText.withPeriod(school?.end ?? 0) }
        public var arriveBy: Int { school?.arriveBy ?? school?.start ?? 0 }
        public var latest: Int { school?.latest ?? arriveBy }
        public var arriveByDate: Date { today.date(minute: arriveBy, calendar: calendar) }
        public var latestDate: Date { today.date(minute: latest, calendar: calendar) }
        public var arriveByLabel: String { TimeText.withPeriod(arriveBy) }
        public var latestLabel: String { TimeText.withPeriod(latest) }
        /// The Going row (board G4): "Bus 12 · leave 7:05", as Settings' To school; or none yet.
        public var goingText: String { goingLine.text }
        /// The way's picture, or none until a way is set.
        public var goingPicture: String? { goingLine.picture }
        private var goingLine: (picture: String?, text: String) {
            guard let school else { return (nil, L10n.tr("hub.more.buses.none")) }
            return SettingsModel.going(trip: SettingsModel.schoolTrip(kid: kid, routines: routines, today: today),
                                       plan: busPlan, school: school)
        }
        public var isChanged: Bool { school != original || medal != originalMedal }
        public var canSave: Bool {
            guard let school else { return false }
            return isChanged && school.end > school.start && !school.days.isEmpty
        }

        /// This day: the date's own template with School's slice moved; the school record stays.
        var dayTemplateToSave: Routine? {
            guard let school,
                  let current = DayPlanner.template(for: kid, on: day, routines: routines, holidays: [], calendar: calendar),
                  current.blocks.contains(where: { $0.kind == .school }) else { return nil }
            var edit = TemplateEdit(blocks: current.blocks)
            if let index = edit.blocks.firstIndex(where: { $0.kind == .school }) {
                _ = edit.setStart(ofBlock: index, to: school.arriveBy ?? school.start)
            }
            if let index = edit.blocks.firstIndex(where: { $0.kind == .school }) {
                _ = edit.setEnd(ofBlock: index, to: school.end)
            }
            return Routine.day(day, kid: kid, dayType: DayPlanner.dayType(on: day, holidays: [], calendar: calendar),
                               blocks: edit.blocks)
        }

        /// The weekday template from G5's day with School's slice on the new times (the knobs' rules),
        /// made from the weekday template in use then (a day's own template is not a base).
        var templateToSave: Routine? {
            guard let school,
                  let current = DayPlanner.template(for: kid, on: weekday(from: splitDay),
                                                    routines: routines.filter { $0.onlyOn == nil }, holidays: [],
                                                    calendar: calendar),
                  current.blocks.contains(where: { $0.kind == .school }) else { return nil }
            var edit = TemplateEdit(blocks: current.blocks)
            if let index = edit.blocks.firstIndex(where: { $0.kind == .school }) {
                _ = edit.setStart(ofBlock: index, to: school.arriveBy ?? school.start)
            }
            if let index = edit.blocks.firstIndex(where: { $0.kind == .school }) {
                _ = edit.setEnd(ofBlock: index, to: school.end)
            }
            var blocks = edit.blocks
            if let index = blocks.firstIndex(where: { $0.kind == .school }) {
                blocks[index].trip?.medal = medal
            }
            return Routine(kid: kid, dayType: .weekday, from: splitDay, blocks: blocks)
        }

        /// Today, or the next weekday: the template the medal is read from.
        var nextSchoolDay: Day { weekday(from: today) }

        /// `day`, or the next weekday after it.
        func weekday(from day: Day) -> Day {
            (0..<7).map { day.adding(days: $0, calendar: calendar) }
                .first { $0.weekday(calendar) != .saturday && $0.weekday(calendar) != .sunday } ?? day
        }
    }

    public enum Action: Equatable {
        case task
        case loaded(ScheduleSnapshot?)
        /// The school's year, and whether the school list knows its terms.
        case schoolYearLoaded(SchoolCalendar, termsKnown: Bool)
        /// The family's year, for the kid's days off.
        case familyLoaded(FamilyCalendar)
        case startPicked(Date)
        case endPicked(Date)
        case dayToggled(Weekday)
        case arriveByPicked(Date)
        case latestPicked(Date)
        case medalToggled
        case scopeTapped(Scope)
        /// Board G4 Terms: the S2 MOE calendar switch.
        case moeTermsToggled
        /// Board F2 over G4: open, pick (up to four), "More", Done, Cancel.
        case bringRowTapped
        case bringToggled(KitSlot)
        case bringMoreTapped
        case bringDoneTapped
        case bringClosed
        /// "School ›": G7 change school.
        case changeSchoolTapped
        /// "Going ›": Our buses for this kid (spec: the S3 trip screen, opened from here).
        case goingTapped
        case saveTapped
        /// Board G5 over G4: Today / the next day / Date, then Save or Cancel.
        case fromWhenPicked(FromWhenTabs.Choice)
        case fromWhenDatePicked(Date)
        case fromWhenSaveTapped
        case fromWhenCancelTapped
        /// This day: skip School on the day, or bring it back; saved at once (as G3).
        case skipDayTapped
        case daySkipSaved(Routine)
        case saved(Bool)
        case backTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case openBuses(Kid.ID)
            case changeSchool(Kid.ID)
            case finished
        }
    }

    @Dependency(\.scheduleStore) var scheduleStore
    @Dependency(\.holidays) var holidays
    @Dependency(\.schoolDirectory) var schoolDirectory
    @Dependency(\.uuid) var uuid

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            let calendar = state.calendar
            switch action {
            case .task:
                let kid = state.kid
                // Spec G5: every year the 14-day window touches (late December reads January too).
                let years = FromWhenTabs.years(from: state.today, calendar: state.calendar)
                return .run { [scheduleStore, holidays, schoolDirectory] send in
                    let snapshot = try? await scheduleStore.load()
                    var publicHolidays: [Day] = []
                    for year in years { publicHolidays += await holidays.holidays(year).map(\.day) }
                    let family = await schoolDirectory.family(kids: snapshot?.kids ?? [], publicHolidays: publicHolidays)
                    let directoryID = snapshot?.kids.first { $0.id == kid }?.school?.directoryID
                    let known = if let directoryID {
                        await schoolDirectory.schools().first { $0.id == directoryID }?.followsMoeTerms != nil
                    } else { false }
                    await send(.loaded(snapshot))
                    await send(.familyLoaded(family))
                    await send(.schoolYearLoaded(family.schools[kid] ?? .none, termsKnown: known))
                }

            case let .familyLoaded(family):
                state.family = family
                return .none

            case let .schoolYearLoaded(year, known):
                state.schoolYear = year
                state.termsKnown = known
                return .none

            case let .loaded(snapshot):
                let kid = snapshot?.kids.first { $0.id == state.kid }
                state.stored = kid
                state.school = kid?.school
                state.original = kid?.school
                state.routines = snapshot?.routines ?? []
                state.busPlan = snapshot?.busPlans.route(kid: state.kid)
                let template = DayPlanner.template(for: state.kid, on: state.nextSchoolDay, routines: state.routines,
                                                   holidays: [], calendar: calendar)
                state.medal = template?.blocks.first { $0.kind == .school }?.trip?.medal ?? true
                state.originalMedal = state.medal
                return .none

            case let .startPicked(date):
                // Arrive by and Latest move with the start, Latest keeping its grace.
                guard let school = state.school else { return .none }
                let start = Day.minute(of: date, calendar: calendar)
                let moved = school.moved(sliceStart: (school.arriveBy ?? school.start) + start - school.start,
                                         sliceEnd: school.end)
                state.school = moved
                return .none

            case let .endPicked(date):
                state.school?.end = Day.minute(of: date, calendar: calendar)
                state.school?.dayHours = nil
                return .none

            case let .dayToggled(day):
                if state.school?.days.contains(day) == true { state.school?.days.remove(day) } else {
                    state.school?.days.insert(day)
                }
                return .none

            case let .arriveByPicked(date):
                guard var school = state.school else { return .none }
                let arrive = Day.minute(of: date, calendar: calendar)
                let grace = school.lateGrace ?? 10
                school.arriveBy = arrive
                school.latest = arrive + grace
                state.school = school
                return .none

            case let .latestPicked(date):
                let latest = Day.minute(of: date, calendar: calendar)
                let arriveBy = state.arriveBy
                state.school?.latest = max(latest, arriveBy)
                return .none

            case .medalToggled:
                state.medal.toggle()
                return .none

            case let .scopeTapped(scope):
                state.editScope = scope
                return .none

            case .moeTermsToggled:
                if let uses = state.school?.usesMoeTerms { state.school?.usesMoeTerms = !uses }
                return .none

            case .bringRowTapped:
                state.bringWas = state.bring
                state.isPickingMoreBring = false
                return .none

            case let .bringToggled(slot):
                var list = state.bring
                if let index = list.firstIndex(where: { $0.picture == slot.rawValue }) {
                    list.remove(at: index)
                } else if list.count < ItemMission.most {
                    list.append(ItemMission(id: uuid(), name: ItemForm.bringLabel(for: slot.rawValue), picture: slot.rawValue))
                }
                state.school?.bring = list.isEmpty ? nil : list
                return .none

            case .bringMoreTapped:
                state.isPickingMoreBring.toggle()
                return .none

            case .bringDoneTapped:
                state.bringWas = nil
                return .none

            case .bringClosed:
                if let was = state.bringWas { state.school?.bring = was.isEmpty ? nil : was }
                state.bringWas = nil
                return .none

            case .goingTapped:
                return .send(.delegate(.openBuses(state.kid)))

            case .skipDayTapped:
                guard let current = state.dayTemplate,
                      let index = current.blocks.firstIndex(where: { $0.kind == .school }) else { return .none }
                var blocks = current.blocks
                blocks[index].isSkipped.toggle()
                let routine = Routine.day(state.day, kid: state.kid,
                                          dayType: DayPlanner.dayType(on: state.day, holidays: [], calendar: state.calendar),
                                          blocks: blocks)
                return .run { [scheduleStore] send in
                    do {
                        try await scheduleStore.saveRoutine(routine)
                        await send(.daySkipSaved(routine))
                    } catch {
                        await send(.saved(false))
                    }
                }

            case let .daySkipSaved(routine):
                state.routines.removeAll { $0.kid == routine.kid && $0.onlyOn == routine.onlyOn }
                state.routines.append(routine)
                return .none

            case .changeSchoolTapped:
                return .send(.delegate(.changeSchool(state.kid)))

            case .saveTapped:
                guard state.canSave, state.stored != nil else { return .none }
                if state.editScope == .allDays {
                    // Spec G5: All days asks from when first, on the day carried from G1 as This day moved
                    // it (#250); from the List or Settings none, so Today.
                    let opening = FromWhenTabs.opening(shown: state.carriedDay, next: state.nextDay, today: state.today)
                    state.fromWhen = opening.choice
                    state.fromWhenDate = opening.date
                    return .none
                }
                // This day: only the date's template changes (spec "Edit scope").
                let routine = state.dayTemplateToSave
                return .run { [scheduleStore] send in
                    do {
                        if let routine { try await scheduleStore.saveRoutine(routine) }
                        await send(.saved(true))
                    } catch {
                        await send(.saved(false))
                    }
                }

            case let .fromWhenPicked(choice):
                state.fromWhen = choice
                return .none

            case let .fromWhenDatePicked(date):
                state.fromWhen = .date
                state.fromWhenDate = max(Day(date, calendar: calendar), state.today)
                return .none

            case .fromWhenCancelTapped:
                state.fromWhen = nil
                return .none

            case .fromWhenSaveTapped:
                guard state.fromWhen != nil, state.canSave, var kid = state.stored else { return .none }
                // The school record has no date: it changes now, as an All days save on the clock does;
                // the weekday template changes from G5's day.
                kid.school = state.school
                let routine = state.templateToSave
                state.fromWhen = nil
                return .run { [scheduleStore, kid] send in
                    do {
                        try await scheduleStore.saveKid(kid)
                        if let routine { try await scheduleStore.saveRoutine(routine) }
                        await send(.saved(true))
                    } catch {
                        await send(.saved(false))
                    }
                }

            case let .saved(ok):
                guard ok else {
                    state.saveError = L10n.tr("day.save_failed")
                    return .none
                }
                return .send(.delegate(.finished))

            case .backTapped:
                return .send(.delegate(.finished))

            case .delegate:
                return .none
            }
        }
    }
}
