import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import HolidayProvider
import Localization
import ScheduleStore
import SchoolDirectory
import Strings

/// K1 · School calendar (spec K1, boards K1, K1o, K1n; layout v74): a read-only year of each kid's
/// school days off and the public holidays, opened from the calendar button on the kid home without
/// the lock. Twelve month cards; a tapped card opens over the year.
@Reducer
public struct SchoolYearFeature {
    @ObservableState
    public struct State: Equatable {
        /// Day or night (board K1n), the kid home's look; the app keeps it in step.
        public var look: KidLook
        /// The family's year arrives from the store; nothing is drawn before it.
        public var phase: Phase = .loading
        /// The month opened over the year (1–12); nil shows the year alone.
        public var openMonth: Int?
        /// Every word this screen shows comes from here (views hold no values).
        public var strings = Localizer.injected

        public init(look: KidLook = .day) {
            self.look = look
        }

        @CasePathable
        public enum Phase: Equatable {
            case loading
            case ready(Year)
        }

        /// What the store and the bundled lists give: today, the kids, the years with data and the
        /// family's year (breaks and public holidays across those years).
        public struct Year: Equatable {
            public var today: Day
            public var kids: [Kid]
            /// The years the data has, the current one first (spec: "Only the years the school data has").
            public var years: [Int]
            public var picked: Int
            public var family: FamilyCalendar
            public var months: [MonthGrid]

            public init(today: Day, kids: [Kid], years: [Int], family: FamilyCalendar, calendar: Calendar) {
                self.today = today
                self.kids = kids
                self.years = years
                picked = today.year
                self.family = family
                months = MonthGrid.year(today.year, calendar: calendar)
            }
        }

        /// One month as a card shows it.
        public struct Month: Equatable, Identifiable, Sendable {
            public var month: Int
            public var title: String
            public var weeks: [[CalendarCell.Mark?]]
            public var id: Int { month }
        }

        /// Everything the view draws once the year is loaded.
        public struct Screen {
            /// The year tabs (`CrayonTabs` items).
            public var tabs: [(Int, String, KidFace.Badge?)]
            public var pickedYear: Int
            public var legend: [CalendarLegend.Item]
            /// "M" … "S" on the cards (layout v74); "Mon" … "Sun" on the open month.
            public var weekdays: [String]
            public var openWeekdays: [String]
            public var months: [Month]
            /// The open month, titled "{Month} {Year}".
            public var open: Month?
        }

        /// nil while loading: the view draws only the back button.
        public var screen: Screen? {
            guard case let .ready(year) = phase else { return nil }
            // Each kid's days off once per screen (the cells look them up 365 times).
            let off = year.kids.map { (colorIndex: $0.colorIndex, days: year.family.breakDays($0.id)) }
            let months = year.months.map { grid in
                Month(month: grid.month, title: DayText.monthLong(grid.month),
                      weeks: grid.weeks.map { week in week.map { $0.map { mark($0, off: off, year: year) } } })
            }
            let open = openMonth.flatMap { number in months.first { $0.month == number } }.map { month in
                Month(month: month.month, title: strings.tr("calendar.month_year", month.title, "\(year.picked)"),
                      weeks: month.weeks)
            }
            return Screen(tabs: year.years.map { ($0, "\($0)", nil) }, pickedYear: year.picked,
                          legend: legend(year), weekdays: DayText.mondayFirst.map(DayText.initial),
                          openWeekdays: DayText.mondayFirst.map(DayText.shortName), months: months, open: open)
        }

        /// Spec K1 "Marks": the kids off that day (in the family's order), a public holiday, today.
        private func mark(_ day: Day, off: [(colorIndex: Int, days: Set<Day>)], year: Year) -> CalendarCell.Mark {
            CalendarCell.Mark(number: "\(day.day)", kids: off.filter { $0.days.contains(day) }.map(\.colorIndex),
                              isHoliday: year.family.publicHolidays.contains(day), isToday: day == year.today)
        }

        /// The key (board K1): each kid at school with their face, "Both off" when the family has
        /// exactly two kids and both are at school (spec v74), then "Public holiday" and "Today". A kid
        /// at home has no school days off, so is not listed.
        private func legend(_ year: Year) -> [CalendarLegend.Item] {
            let atSchool = year.kids.filter { $0.school != nil }
            var items = atSchool.map { kid in
                CalendarLegend.Item(face: KidFace.Badge(face: kid.face, colorIndex: kid.colorIndex),
                                    swatch: CalendarCell.Mark(number: "", kids: [kid.colorIndex]),
                                    label: strings.tr("calendar.kid_off", kid.name))
            }
            if year.kids.count == 2, atSchool.count == 2 {
                items.append(CalendarLegend.Item(swatch: CalendarCell.Mark(number: "", kids: atSchool.map(\.colorIndex)),
                                                 label: strings.tr("calendar.both_off")))
            }
            items.append(CalendarLegend.Item(swatch: CalendarCell.Mark(number: Self.holidaySample, isHoliday: true),
                                             label: strings.tr("calendar.public_holiday")))
            items.append(CalendarLegend.Item(swatch: CalendarCell.Mark(number: "\(year.today.day)", isToday: true),
                                             label: strings.tr("calendar.today")))
            return items
        }

        /// The numeral on the key's public-holiday swatch (board K1: "25").
        static let holidaySample = "25"
    }

    public enum Action: Equatable {
        case task
        /// The root's 1-second tick: a new day reloads the year, so today's mark moves at midnight.
        case tick(Date)
        case loaded(State.Year)
        case yearTapped(Int)
        case monthTapped(Int)
        /// The open month's "×".
        case closeTapped
        /// A tap outside the open month.
        case dimTapped
        /// "‹": back to the home it came from.
        case backTapped
        case delegate(Delegate)

        @CasePathable
        public enum Delegate: Equatable {
            case finished
        }
    }

    @Dependency(\.calendar) var calendar
    @Dependency(\.date) var date
    @Dependency(\.scheduleStore) var scheduleStore
    @Dependency(\.holidays) var holidays
    @Dependency(\.schoolDirectory) var schoolDirectory

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                return load(today: Day(date.now, calendar: calendar))

            case let .tick(now):
                guard case let .ready(year) = state.phase, Day(now, calendar: calendar) != year.today else { return .none }
                return load(today: Day(now, calendar: calendar))

            case var .loaded(year):
                // A reload (a new day) keeps the year the person picked, while it still has data.
                if case let .ready(old) = state.phase, old.picked != year.picked, year.years.contains(old.picked) {
                    year.picked = old.picked
                    year.months = MonthGrid.year(old.picked, calendar: calendar)
                }
                state.phase = .ready(year)
                return .none

            case let .yearTapped(picked):
                guard case var .ready(year) = state.phase, year.years.contains(picked) else { return .none }
                state.openMonth = nil
                year.picked = picked
                year.months = MonthGrid.year(picked, calendar: calendar)
                state.phase = .ready(year)
                return .none

            case let .monthTapped(month):
                guard (1...12).contains(month) else { return .none }
                state.openMonth = month
                return .none

            case .closeTapped, .dimTapped:
                state.openMonth = nil
                return .none

            case .backTapped:
                return .send(.delegate(.finished))

            case .delegate:
                return .none
            }
        }
    }

    /// The family's year as of `today`: this year always, next year when its lists are out.
    private func load(today: Day) -> Effect<Action> {
        .run { [calendar, scheduleStore, holidays, schoolDirectory] send in
            let snapshot = try? await scheduleStore.load()
            // This year always; next year when its lists are out (2026–2027 now).
            var years = [today.year]
            var list = await holidays.holidays(today.year)
            let next = await holidays.holidays(today.year + 1)
            if !next.isEmpty {
                years.append(today.year + 1)
                list += next
            }
            let kids = snapshot?.kids ?? []
            let family = await schoolDirectory.family(
                kids: kids, publicHolidays: list.map(\.day),
                holidayNames: Dictionary(list.map { ($0.day, $0.name) }, uniquingKeysWith: { first, _ in first }))
            await send(.loaded(State.Year(today: today, kids: kids, years: years, family: family, calendar: calendar)))
        }
    }
}
