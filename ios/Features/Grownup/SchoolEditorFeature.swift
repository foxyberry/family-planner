import ComposableArchitecture
import DesignSystem
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
/// the school record and a new weekday template from today with School's slice on the new times; from a
/// later day it stores the kid's one waiting change instead (spec G5 "What Settings shows meanwhile",
/// #255), which templates read from its day and Home writes in on that day. Its "From {d Mon} ·
/// {hours} ›" row turns this G4 to it, with "Cancel this change" (asked first).
/// **This day** keeps the record and saves the day's own template with School's slice moved (a late
/// start, an early dismissal).
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
        /// The form edits the waiting hours change (opened from its "From {d Mon} · {hours} ›" row),
        /// not today's hours.
        public var editsWaiting: Bool
        /// "Cancel this change" asks first ("Cancel the change from 18 Nov?").
        public var isConfirmingCancel = false
        /// Board G5: the "Change from when?" card is open, with its choice and date.
        public var fromWhen: FromWhenTabs.Choice?
        public var fromWhenDate: Day
        /// The family's year: the kid's days off (school holidays, public holidays).
        public var family = FamilyCalendar()
        /// The school's year, for the Terms row (MOE calendar or its own dates).
        public var schoolYear: SchoolCalendar = .none
        /// The school list says whether this school follows MOE terms (a known MOE school, or one
        /// with its own term dates): then the Terms row is text only (spec G4 Terms).
        public var termsKnown = false
        /// Board F2 over G4: the Bring card is open, and the bring list when it opened (Cancel puts it back).
        public var bringWas: [ItemMission]?
        /// Issue 024: the school's lists when the Before or Back card opened (Cancel puts them back).
        public var listsWas: EventLists?
        /// Board F7 over G4: the Back card is open.
        public var isBackOpen = false
        /// The kid's bundles (the Before card's chips) and the family's items (an item after School
        /// moves Back to it).
        public var bundles: [MissionBundle] = []
        public var items: [ScheduleItem] = []
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

        public init(kid: Kid.ID, today: Day, nowMinute: Int = 0, shownDay: Day? = nil, editsWaiting: Bool = false,
                    calendar: Calendar) {
            self.kid = kid
            self.today = today
            self.nowMinute = nowMinute
            self.shownDay = shownDay
            self.editsWaiting = editsWaiting
            self.calendar = calendar
            fromWhenDate = today
        }

        /// The form's values once the kid is known: the waiting change when the form edits it (none
        /// left, today's), else today's hours; the medal from the template they start.
        mutating func startForm() {
            let waiting = editsWaiting ? stored?.pendingHours : nil
            editsWaiting = waiting != nil
            school = waiting?.school ?? stored?.school
            original = school
            medal = templateMedal(on: waiting?.from ?? today, routines: shown)
            originalMedal = medal
        }

        /// The kid's templates as each date reads them (a waiting change from its day on).
        var shown: [Routine] { stored?.readingWaitingHours(routines) ?? routines }

        /// The medal School wins on the weekday template in use from `day` (today, or the next weekday).
        func templateMedal(on day: Day, routines: [Routine]) -> Bool {
            schoolTrip(on: day, routines: routines)?.medal ?? true
        }

        /// School's trip on the weekday template in use from `day`; none when School has no way there.
        func schoolTrip(on day: Day, routines: [Routine]) -> Trip? {
            let template = DayPlanner.template(for: kid, on: weekday(from: day), routines: routines, holidays: [],
                                               calendar: calendar)
            return template?.blocks.first { $0.kind == .school }?.trip
        }

        /// The Medal switch is off (the 40 % look) while School has no trip: the medal lives on the
        /// trip, so there is nothing to switch (design decision, 2026-11-22).
        public var canSwitchMedal: Bool {
            schoolTrip(on: (editsWaiting ? waiting?.from : nil) ?? today, routines: shown) != nil
        }
        /// The Medal switch shows off without a trip, as the item editor's does (no trip, no medal).
        public var medalIsOn: Bool { canSwitchMedal && medal }

        // MARK: The waiting hours change (spec G5 "What Settings shows meanwhile")

        /// The kid's waiting hours change, if one waits.
        public var waiting: PendingHours? { stored?.pendingHours }
        /// Under When (today's hours): "From 18 Nov · 8:30 am – 2:00 pm" while a change waits; not on
        /// the waiting change itself.
        public var waitingLine: String? {
            guard !editsWaiting, let waiting else { return nil }
            return strings.tr("school_edit.waiting", DayText.dayMonth(waiting.from, calendar: calendar),
                              TimeText.hours(waiting.school.start, waiting.school.end))
        }
        /// The waiting change's "Cancel this change" (`lateText`); none on today's hours.
        public var cancelChangeTitle: String? { editsWaiting ? strings.tr("school_edit.cancel_change") : nil }
        /// The ConfirmCard under the link (spec #255): "Cancel the change from 18 Nov?".
        public var cancelConfirmTitle: String {
            strings.tr("school_edit.cancel_change.title", DayText.dayMonth(waiting?.from ?? today, calendar: calendar))
        }
        public var cancelConfirmAction: String { strings.tr("school_edit.cancel_change.confirm") }
        public var cancelConfirmKeep: String { strings.tr("school_edit.cancel_change.keep") }

        /// The kid's days off.
        var daysOff: Set<Day> { family.daysOff(kid) }

        /// Whether School is on `day` for the saved school: one of its days, a school day (not a day
        /// off) and in the day's template (skipped or not, so a skip does not move This day).
        func hasSchool(on day: Day) -> Bool {
            guard let days = stored?.school?.days, days.contains(day.weekday(calendar)),
                  DayPlanner.dayType(on: day, holidays: daysOff, calendar: calendar) == .weekday else { return false }
            return DayPlanner.template(for: kid, on: day, routines: shown, holidays: daysOff, calendar: calendar)?
                .blocks.contains { $0.kind == .school } == true
        }

        /// The day carried from G1 as This day moved it (G5 opens on it, spec G5 #250); nil from the
        /// List or Settings, so G5 opens on Today. The waiting change opens G5 on its own day.
        var carriedDay: Day? {
            if editsWaiting, let waiting { return waiting.from }
            return shownDay == nil ? nil : day
        }

        /// The first day from `start` that has School (a year ahead at most); today counts only until
        /// School is over.
        func schoolDay(onOrAfter start: Day) -> Day? {
            (0..<366).lazy.map { start.adding(days: $0, calendar: self.calendar) }
                .filter { $0 != self.today || self.nowMinute < (self.stored?.school?.end ?? 0) }
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

        // MARK: What the view shows (it holds no values of its own)

        /// Boards G2 / G4: the side column's This day / All days tabs.
        public var scopeTabs: [(Scope, String)] {
            [(.thisDay, strings.tr("editor.scope.this_day")), (.allDays, strings.tr("editor.scope.all_days"))]
        }
        /// The side column's foot: Save changes.
        public var saveTitle: String { strings.tr("editor.primary.save") }
        /// The rows' labels: School, When, Days, Arrive by (then "latest"), Terms, Going, Bring, Medal.
        public var schoolLabel: String { strings.tr("settings.school") }
        public var whenLabel: String { strings.tr("editor.row.when") }
        public var daysLabel: String { strings.tr("editor.row.days") }
        public var arriveByRowLabel: String { strings.tr("s2.arrive_by") }
        public var latestWord: String { strings.tr("s2.latest") }
        public var termsLabel: String { strings.tr("settings.terms") }
        public var goingLabel: String { strings.tr("going.label") }
        /// The Bring caption on the Before card (board F2).
        public var bringLabel: String { strings.tr("before.bring") }
        /// Issue 024 (board G4, layout v77): Before (bundles and Bring) and Back (the way home).
        public var beforeLabel: String { strings.tr("editor.row.before") }
        public var backLabel: String { strings.tr("editor.row.back") }
        public var bundlesCaption: String { strings.tr("before.bundles") }
        public var takesLabel: String { strings.tr("back.takes") }
        public var lists: EventLists { school?.lists ?? EventLists() }
        /// The Before row's value: the picked bundles' names, then the Bring names; nil is "Nothing".
        public var beforeText: String? {
            let names = bundles.filter { lists.before.contains($0.id) }.map(\.name) + bring.map(\.name)
            return names.isEmpty ? nil : names.joined(separator: " · ")
        }
        public var bundleChips: [BundleChip] {
            bundles.filter { $0.kid == kid }.map { .init(id: $0.id, name: $0.name, isOn: lists.before.contains($0.id)) }
        }
        /// Back is on School only while no item follows it for this kid (it is then the chain's end).
        public var showsBack: Bool { !items.contains { $0.after == .school && $0.audience.includes(kid) } }
        public var backChoices: [ChoiceCircles.Choice] { BackCopy.choices(lists.wayHome, strings: strings) }
        public var showsTakes: Bool { lists.wayHome != .none }
        /// Board F7's "Takes" stepper; nil for None.
        public var backTakes: BackCard.Stepper? {
            guard showsTakes else { return nil }
            return BackCard.Stepper(label: takesLabel, value: homeAfterText, canMinus: homeAfterEnds.canLower,
                                    canPlus: homeAfterEnds.canRaise)
        }
        public var homeAfterText: String { strings.tr("c2.minutes", lists.homeAfter) }
        public var homeAfterEnds: StepEnds { StepRange.homeAfter.ends(lists.homeAfter) }
        public var backText: String? { BackCopy.text(lists, strings: strings) }
        public var backPicture: KitSlot? { BackCopy.picture(lists) }

        /// Changes the school's lists in place.
        mutating func editLists(_ change: (inout EventLists) -> Void) {
            var value = lists
            change(&value)
            school?.lists = value
        }
        public var medalLabel: String { strings.tr("editor.row.medal") }
        /// The Bring row with nothing to bring.
        public var nothingText: String { strings.tr("editor.row.nothing") }
        /// Board F2: the card's Done and Cancel, and "More" (the whole kit).
        public var bringDoneTitle: String { strings.tr("c5.done") }
        public var bringCancelTitle: String { strings.tr("card.cancel") }
        public var bringMoreTitle: String { strings.tr("picker.more") }
        /// The Days row's chip for `day` is on: School is on that weekday.
        public func isDayOn(_ day: Weekday) -> Bool { school?.days.contains(day) == true }
        public var schoolName: String { school?.name ?? "" }
        /// "From 5 Jan: Example Primary School" while a G7 change waits for its day.
        public var pendingLine: String? {
            guard let pending = stored?.pendingSchool else { return nil }
            return L10n.tr("change_school.pending", DayText.dayMonth(pending.from, calendar: calendar),
                         pending.school?.name ?? L10n.tr("settings.child.home"))
        }
        /// Board G4's side line: "Every school day", or the days as chips.
        public var everyTitle: String { DayText.chips(school?.days ?? []) }
        /// Spec G2 "School is an event": This day's side column as G3, "{Day d Mon} only" then "Skip this day".
        public var isThisDay: Bool { editScope == .thisDay }
        public var thisDayTitle: String { L10n.tr("editor.this_day.only", DayText.short(day, calendar: calendar)) }
        /// The day's template (its own one when it has it), as that date reads it.
        var dayTemplate: Routine? {
            DayPlanner.template(for: kid, on: day, routines: shown, holidays: [], calendar: calendar)
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
                  let current = dayTemplate, current.blocks.contains(where: { $0.kind == .school }) else { return nil }
            var edit = TemplateEdit(blocks: current.blocks)
            if let index = edit.blocks.firstIndex(where: { $0.kind == .school }) {
                _ = edit.setStart(ofBlock: index, to: school.arriveBy ?? school.start)
            }
            if let index = edit.blocks.firstIndex(where: { $0.kind == .school }) {
                _ = edit.setEnd(ofBlock: index, to: school.end)
            }
            return Routine.day(day, kid: kid, dayType: DayPlanner.dayType(on: day, holidays: [], calendar: calendar),
                               blocks: storing(edit.blocks, on: day))
        }

        /// What a day's own template stores: while a change waits there, School on the waiting hours
        /// goes back to today's record (#255: a day reads School by date, never a copy).
        func storing(_ blocks: [RoutineBlock], on day: Day) -> [RoutineBlock] {
            let raw = DayPlanner.template(for: kid, on: day, routines: routines, holidays: [], calendar: calendar)?.blocks
            return stored?.storingSchool(blocks, on: day, stored: raw ?? blocks) ?? blocks
        }

        /// A save from today: the weekday template from today with School's slice on the new times (the
        /// knobs' rules), made from the weekday template in use (a day's own template is not a base). A
        /// save from a later day writes no template: the waiting change is read from its day (#255).
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
        case bundleToggled(MissionBundle.ID)
        case backRowTapped
        case wayHomePicked(String)
        case homeAfterStepped(Int)
        case backDoneTapped
        case backClosed
        /// "School ›": G7 change school.
        case changeSchoolTapped
        /// "Going ›": Our buses for this kid (spec: the S3 trip screen, opened from here).
        case goingTapped
        case saveTapped
        /// "From {d Mon} · {hours} ›": the form edits the waiting hours change.
        case waitingRowTapped
        /// "Cancel this change": asks first; "Cancel it" removes the waiting change, "Keep" keeps it.
        case cancelChangeTapped
        case cancelConfirmed
        case cancelKept
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
                state.stored = snapshot?.kids.first { $0.id == state.kid }
                state.routines = snapshot?.routines ?? []
                state.bundles = snapshot?.bundles ?? []
                state.items = snapshot?.items ?? []
                state.busPlan = snapshot?.busPlans.route(kid: state.kid)
                state.startForm()
                return .none

            case .waitingRowTapped:
                guard state.waiting != nil else { return .none }
                state.editsWaiting = true
                state.editScope = .allDays
                state.startForm()
                return .none

            case .cancelChangeTapped:
                guard state.editsWaiting, state.waiting != nil else { return .none }
                state.isConfirmingCancel = true
                return .none

            case .cancelKept:
                state.isConfirmingCancel = false
                return .none

            case .cancelConfirmed:
                state.isConfirmingCancel = false
                guard state.editsWaiting, var kid = state.stored, kid.pendingHours != nil else { return .none }
                // Only the waiting change goes: it wrote nothing into the templates (#255).
                kid.pendingHours = nil
                return .run { [scheduleStore, kid] send in
                    do {
                        try await scheduleStore.saveKid(kid)
                        await send(.saved(true))
                    } catch {
                        await send(.saved(false))
                    }
                }

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
                guard state.canSwitchMedal else { return .none }
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
                state.listsWas = state.school?.lists
                state.isPickingMoreBring = false
                return .none

            case let .bundleToggled(id):
                state.editLists { lists in
                    if let index = lists.before.firstIndex(of: id) { lists.before.remove(at: index) } else { lists.before.append(id) }
                }
                return .none

            case .backRowTapped:
                state.listsWas = state.school?.lists
                state.isBackOpen = true
                return .none

            case let .wayHomePicked(id):
                if let way = WayHome(rawValue: id) { state.editLists { $0.wayHome = way } }
                return .none

            case let .homeAfterStepped(step):
                state.editLists { $0.homeAfter = StepRange.homeAfter.clamp($0.homeAfter + 5 * step) }
                return .none

            case .backDoneTapped:
                state.isBackOpen = false
                state.listsWas = nil
                return .none

            case .backClosed:
                let was = state.listsWas
                state.school?.lists = was
                state.isBackOpen = false
                state.listsWas = nil
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
                state.listsWas = nil
                return .none

            case .bringClosed:
                if let was = state.bringWas { state.school?.bring = was.isEmpty ? nil : was }
                let was = state.listsWas
                state.school?.lists = was
                state.bringWas = nil
                state.listsWas = nil
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
                                          blocks: state.storing(blocks, on: state.day))
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
                guard state.fromWhen != nil, state.canSave, let stored = state.stored, let school = state.school
                else { return .none }
                // From today: the record and the weekday template now (a waiting change is dropped). From a
                // later day: the kid's one waiting change, its medal only when it differs from the
                // template's then; no template is written (#255: dates read it from its day).
                let from = state.splitDay
                let waits = from > state.today
                let stays = state.templateMedal(on: from, routines: state.routines)
                let medal: Bool? = waits && state.medal != stays ? state.medal : nil
                let kid = stored.savingSchool(school, from: from, today: state.today, medal: medal)
                let routine = waits ? nil : state.templateToSave
                // From today the change reaches the later templates that follow the old record too.
                let changedMedal = state.medal != state.originalMedal ? state.medal : nil
                let following = waits ? [] : stored.school.map {
                    kid.followingSchool(state.routines, from: state.today, old: $0, medal: changedMedal)
                } ?? []
                state.fromWhen = nil
                return .run { [scheduleStore, kid] send in
                    do {
                        try await scheduleStore.saveKid(kid)
                        for later in following { try await scheduleStore.saveRoutine(later) }
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
