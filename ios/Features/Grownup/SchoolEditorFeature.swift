import ComposableArchitecture
import Domain
import Foundation
import KitArt
import ScheduleStore
import SchoolDirectory
import Strings

/// G4 · Edit School (spec "G4", layout v47): School's hours, days, Arrive by and Latest, Terms, how
/// the kid goes, Bring and the medal. **All days** writes the school record and a new weekday template
/// from today with School's slice on the new times (as an All days save on the clock does). **This
/// day** keeps the record and saves the day's own template with School's slice moved (a late start,
/// an early dismissal).
@Reducer
public struct SchoolEditorFeature {
    /// "This day" or "All days" (spec "Edit scope").
    public enum Scope: Hashable, Sendable { case thisDay, allDays }

    @ObservableState
    public struct State: Equatable {
        public var kid: Kid.ID
        /// The date "This day" changes (the clock's day, or today from the List).
        public var day: Day
        public var editScope: Scope = .allDays
        /// The school's year, for the Terms row (MOE calendar or its own dates).
        public var schoolYear: SchoolCalendar = .none
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
        public var calendar: Calendar
        public var saveError: String?

        public init(kid: Kid.ID, today: Day, day: Day? = nil, calendar: Calendar) {
            self.kid = kid
            self.today = today
            self.day = day ?? today
            self.calendar = calendar
        }

        /// Board G4 Terms: "MOE 2026 · Term 4 ends 20 Nov", or the school's own term end.
        public var termsText: String {
            SettingsModel.terms(schoolYear, today: today, dayCalendar: calendar) ?? L10n.tr("editor.row.nothing")
        }
        /// The S2 MOE switch shows for a school that can follow MOE terms.
        public var showsMoeCheck: Bool { school?.usesMoeTerms == true || schoolYear.isMoe }
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
        /// Board G4's side line: "Every school day", or the days as chips.
        public var everyTitle: String { DayText.chips(school?.days ?? []) }
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
        /// The Going row: "1, 2 · walk 10 min", or none yet.
        public var goingText: String {
            busPlan.map { L10n.tr("hub.more.buses.value", $0.services.joined(separator: ", "), $0.walk) }
                ?? L10n.tr("hub.more.buses.none")
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

        /// The weekday template from today with School's slice on the new times (the knobs' rules).
        var templateToSave: Routine? {
            guard let school,
                  let current = DayPlanner.template(for: kid, on: nextSchoolDay, routines: routines, holidays: [],
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
            return Routine(kid: kid, dayType: .weekday, from: today, blocks: blocks)
        }

        /// Today, or the next weekday: the template the change starts from.
        var nextSchoolDay: Day {
            (0..<7).map { today.adding(days: $0, calendar: calendar) }
                .first { $0.weekday(calendar) != .saturday && $0.weekday(calendar) != .sunday } ?? today
        }
    }

    public enum Action: Equatable {
        case task
        case loaded(ScheduleSnapshot?)
        case schoolYearLoaded(SchoolCalendar)
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
        /// "Going ›": Our buses for this kid (spec: the S3 trip screen, opened from here).
        case goingTapped
        case saveTapped
        case saved(Bool)
        case backTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case openBuses(Kid.ID)
            case finished
        }
    }

    @Dependency(\.scheduleStore) var scheduleStore
    @Dependency(\.schoolDirectory) var schoolDirectory
    @Dependency(\.uuid) var uuid

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            let calendar = state.calendar
            switch action {
            case .task:
                let kid = state.kid
                return .run { [scheduleStore, schoolDirectory] send in
                    let snapshot = try? await scheduleStore.load()
                    let family = await schoolDirectory.family(kids: snapshot?.kids ?? [], publicHolidays: [])
                    await send(.loaded(snapshot))
                    await send(.schoolYearLoaded(family.schools[kid] ?? .none))
                }

            case let .schoolYearLoaded(year):
                state.schoolYear = year
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

            case .saveTapped:
                guard state.canSave, var kid = state.stored else { return .none }
                if state.editScope == .thisDay {
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
                }
                kid.school = state.school
                let routine = state.templateToSave
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
