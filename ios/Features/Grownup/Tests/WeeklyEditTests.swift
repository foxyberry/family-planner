import ComposableArchitecture
import Domain
import Foundation
import Grownup
import HolidayProvider
import ScheduleStore
import SchoolDirectory
import XCTest

/// Boards G2, G3, G5: This day (skip or change one day), Every time (from when?), stop the series.
@MainActor
final class WeeklyEditTests: XCTestCase {
    private typealias F = Fixture
    private let swim = F.weekly()   // Kid A, Mon · Wed 3:30–4:30
    /// Not a public holiday (9 Nov 2026 is Deepavali observed).
    private let tuesday = Day(year: 2026, month: 11, day: 10)

    private func store(_ item: ScheduleItem? = nil, minute: Int = 600, on day: Day = F.monday, shownDay: Day? = nil,
                       school: SchoolCalendar = .none, holidays: @escaping @Sendable (Int) -> [Day] = { _ in [] },
                       saved: LockIsolated<[[ScheduleItem]]> = .init([])) -> TestStoreOf<ItemEditorFeature> {
        let item = item ?? swim
        let now = day.date(minute: minute, calendar: F.calendar)
        let snapshot = F.snapshot(items: [item])
        let store = TestStore(initialState: ItemEditorFeature.State(mode: .editWeekly(item), now: now,
                                                                    calendar: F.calendar, shownDay: shownDay)) {
            ItemEditorFeature()
        } withDependencies: {
            $0.calendar = F.calendar
            $0.date.now = now
            $0.uuid = .incrementing
            $0.scheduleStore.load = { snapshot }
            $0.scheduleStore.save = { item in saved.withValue { $0.append([item]) } }
            $0.scheduleStore.saveAll = { items in saved.withValue { $0.append(items) } }
            $0.holidays.holidays = { year in holidays(year).map { Holiday(day: $0, name: "Example Day") } }
            $0.schoolDirectory.calendar = { _, _ in school }
        }
        store.exhaustivity = .off
        return store
    }

    func testThisDayIsTheDefaultAndSkipSavesAtOnce() async {
        let saved = LockIsolated<[[ScheduleItem]]>([])
        let store = store(saved: saved)
        XCTAssertTrue(store.state.isThisDay)
        XCTAssertEqual(store.state.thisDayTitle, "Mon 9 Nov only")
        XCTAssertEqual(store.state.skipTitle, "Skip this day")
        await store.send(.skipRowTapped)
        await store.receive(\.skipSaved)
        XCTAssertEqual(store.state.skipTitle, "Bring back this day")
        XCTAssertEqual(store.state.thisDayTitle, "Mon 9 Nov only", "the skipped day stays this day")
        XCTAssertEqual(saved.value.last?.first?.skippedDays, [F.monday])
        XCTAssertFalse(store.state.hasChanges, "skipping is saved on its own, not a form change")
        await store.send(.skipRowTapped)
        await store.receive(\.skipSaved)
        XCTAssertEqual(saved.value.last?.first?.skippedDays, [])
        XCTAssertEqual(store.state.skipTitle, "Skip this day")
    }

    func testThisDayIsTheNextDayNotSkipped() {
        var skipped = swim
        skipped.skippedDays = [F.monday]
        XCTAssertEqual(store(skipped).state.thisDayTitle, "Wed 11 Nov only")
    }

    func testThisDaySavesAChangeForThatDayOnly() async {
        let saved = LockIsolated<[[ScheduleItem]]>([])
        let store = store(saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.binding(.set(\.form.end, 1020)))
        await store.send(.saveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(saved.value.last?.first?.id, swim.id)
        XCTAssertEqual(saved.value.last?.first?.end, 990, "the series keeps its times")
        XCTAssertEqual(saved.value.last?.first?.dayChanges, [DayChange(day: F.monday, end: 1020)])
    }

    func testAllDaysAsksFromWhenAndSplitsTheSeries() async {
        let saved = LockIsolated<[[ScheduleItem]]>([])
        let store = store(saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.scopeTapped(.allDays))
        XCTAssertEqual(store.state.everyTitle, "Every Mon and Wed")
        await store.send(.binding(.set(\.form.end, 1020)))
        await store.send(.saveTapped)
        XCTAssertEqual(store.state.fromWhen, .today)
        XCTAssertEqual(store.state.fromWhenTabs.map(\.1), ["Today", "Wed 11 Nov", "Date"], "the day itself, not \"Next Wed\"")
        await store.send(.fromWhenPicked(.next))
        XCTAssertEqual(store.state.fromWhenChoice, .next)
        XCTAssertEqual(store.state.splitDay, Day(year: 2026, month: 11, day: 11))
        await store.send(.fromWhenSaveTapped)
        await store.receive(\.saved)
        await store.receive(\.delegate.finished)
        let items = saved.value.last ?? []
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.first?.recurrence, .weekly([.monday, .wednesday], from: Day(year: 2026, month: 11, day: 1),
                                                        until: Day(year: 2026, month: 11, day: 10)))
        XCTAssertEqual(items.last?.end, 1020)
        XCTAssertEqual(items.last?.recurrence, .weekly([.monday, .wednesday], from: Day(year: 2026, month: 11, day: 11),
                                                       until: nil))
    }

    /// Board G5 (layout v69): the next day of the series is tomorrow, so the middle tab says so.
    func testFromWhenNamesTomorrow() async {
        let store = store(on: tuesday)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.scopeTapped(.allDays))
        await store.send(.binding(.set(\.form.end, 1020)))
        await store.send(.saveTapped)
        XCTAssertEqual(store.state.fromWhenTabs.map(\.1), ["Today", "Tomorrow", "Date"])
        XCTAssertEqual(store.state.fromWhen, .today, "opened from the List: Today")
    }

    /// Spec G5: G2 opened from G1 on a later day opens the card with that day picked: the middle
    /// tab when it is that day, else Date with that date; Save splits the series there.
    func testFromWhenOpensOnTheDayBeingLookedAt() async {
        let saved = LockIsolated<[[ScheduleItem]]>([])
        let later = store(on: tuesday, shownDay: Day(year: 2026, month: 11, day: 18), saved: saved)
        await later.send(.task)
        await later.receive(\.loaded)
        await later.send(.scopeTapped(.allDays))
        await later.send(.binding(.set(\.form.end, 1020)))
        await later.send(.saveTapped)
        XCTAssertEqual(later.state.fromWhen, .date)
        XCTAssertEqual(later.state.fromWhenDateLabel, "18 Nov")
        XCTAssertEqual(later.state.splitDay, Day(year: 2026, month: 11, day: 18))
        await later.send(.fromWhenSaveTapped)
        await later.receive(\.saved)
        XCTAssertEqual(saved.value.last?.last?.recurrence,
                       .weekly([.monday, .wednesday], from: Day(year: 2026, month: 11, day: 18), until: nil))

        let next = store(on: tuesday, shownDay: Day(year: 2026, month: 11, day: 11))
        await next.send(.task)
        await next.receive(\.loaded)
        await next.send(.scopeTapped(.allDays))
        await next.send(.binding(.set(\.form.end, 1020)))
        await next.send(.saveTapped)
        XCTAssertEqual(next.state.fromWhen, .next, "the middle tab is that day")

        // Today, a swimming day before it starts: This day stays today, so G5 opens on Today.
        let today = store(on: F.monday, shownDay: F.monday)
        await today.send(.task)
        await today.receive(\.loaded)
        await today.send(.scopeTapped(.allDays))
        await today.send(.binding(.set(\.form.end, 1020)))
        await today.send(.saveTapped)
        XCTAssertEqual(today.state.fromWhen, .today)
    }

    /// Spec G5: a series with no day in the next 14 days has no middle tab (every month on the 30th,
    /// seen on 10 Nov).
    func testNoDayInTwoWeeksHidesTheMiddleTab() async {
        var monthly = swim
        monthly.recurrence = .monthly(.dayOfMonth(30), from: Day(year: 2026, month: 10, day: 30), until: nil)
        let store = store(monthly, on: tuesday)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.scopeTapped(.allDays))
        await store.send(.binding(.set(\.form.end, 1020)))
        await store.send(.saveTapped)
        XCTAssertEqual(store.state.fromWhenTabs.map(\.0), [.today, .date])
    }

    /// Spec G5 "The middle tab's day": the next day within Runs, never after the series' end; an end
    /// before it hides the tab, whichever way the end is set ("On a date", "End of this term",
    /// "After n times"). Swimming is Mon · Wed from 1 Nov; seen on Tue 10 Nov.
    func testTheMiddleTabIsTheNextDayWithinRuns() async {
        func middle(_ item: ScheduleItem, school: SchoolCalendar = .none) async -> [String] {
            let store = store(item, on: tuesday, school: school)
            await store.send(.task)
            await store.receive(\.loaded)
            await store.send(.scopeTapped(.allDays))
            await store.send(.binding(.set(\.form.end, 1020)))
            await store.send(.saveTapped)
            return store.state.fromWhenTabs.map(\.1)
        }
        let wed11 = Day(year: 2026, month: 11, day: 11)
        let open = await middle(swim)
        XCTAssertEqual(open, ["Today", "Tomorrow", "Date"])
        let endsOnIt = await middle(F.weekly(until: wed11))
        XCTAssertEqual(endsOnIt, ["Today", "Tomorrow", "Date"], "the end day itself still counts")
        let endedToday = await middle(F.weekly(until: tuesday))
        XCTAssertEqual(endedToday, ["Today", "Date"], "On a date: no day after the end")

        var termly = swim
        termly.runsEnd = .term
        let term = SchoolCalendar(terms: [SchoolCalendar.Term(name: "Term 4", start: Day(year: 2026, month: 10, day: 1),
                                                              end: tuesday)])
        let termEnded = await middle(termly, school: term)
        XCTAssertEqual(termEnded, ["Today", "Date"], "End of this term, worked out from the term data")

        var counted = swim
        counted.runsEnd = .count(3)   // 2, 4 and 9 Nov
        let countEnded = await middle(counted)
        XCTAssertEqual(countEnded, ["Today", "Date"], "After 3 times ends on 9 Nov")
    }

    /// Spec G5: an every-month item's middle tab is its next matching day of the month, within Runs.
    func testAMonthlyItemsMiddleTabIsItsNextDayOfTheMonth() async {
        var monthly = swim
        monthly.recurrence = .monthly(.nthWeekday(2, .saturday), from: Day(year: 2026, month: 10, day: 10), until: nil)
        let store = store(monthly, on: tuesday)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.scopeTapped(.allDays))
        await store.send(.binding(.set(\.form.end, 1020)))
        await store.send(.saveTapped)
        XCTAssertEqual(store.state.fromWhenTabs.map(\.1), ["Today", "Sat 14 Nov", "Date"], "2nd Sat")

        var ending = monthly
        ending.recurrence = .monthly(.nthWeekday(2, .saturday), from: Day(year: 2026, month: 10, day: 10),
                                     until: Day(year: 2026, month: 11, day: 13))
        let ended = self.store(ending, on: tuesday)
        await ended.send(.task)
        await ended.receive(\.loaded)
        await ended.send(.scopeTapped(.allDays))
        await ended.send(.binding(.set(\.form.end, 1020)))
        await ended.send(.saveTapped)
        XCTAssertEqual(ended.state.fromWhenTabs.map(\.0), [.today, .date], "its next 2nd Sat is after the end")
    }

    /// Spec G5 "Which screens and days": G2 opened from G1 means the day shown there by "This day";
    /// from the List it is the next day the item happens.
    func testThisDayIsTheDayG1Showed() async {
        let saved = LockIsolated<[[ScheduleItem]]>([])
        let wed18 = Day(year: 2026, month: 11, day: 18)
        let fromClock = store(on: tuesday, shownDay: wed18, saved: saved)
        XCTAssertEqual(fromClock.state.thisDayTitle, "Wed 18 Nov only")
        await fromClock.send(.task)
        await fromClock.receive(\.loaded)
        await fromClock.send(.skipRowTapped)
        await fromClock.receive(\.skipSaved)
        XCTAssertEqual(saved.value.last?.first?.skippedDays, [wed18], "Skip this day skips the shown day")
        XCTAssertEqual(fromClock.state.thisDayTitle, "Wed 18 Nov only")

        XCTAssertEqual(store(on: tuesday).state.thisDayTitle, "Wed 11 Nov only", "from the List: the next day")
        XCTAssertEqual(store(on: tuesday, shownDay: Day(year: 2026, month: 11, day: 12)).state.thisDayTitle,
                       "Mon 16 Nov only", "a shown day without the item: the next day it happens after it")
        XCTAssertEqual(store(on: tuesday, shownDay: F.monday).state.thisDayTitle, "Wed 11 Nov only",
                       "a day before today is never This day")
        XCTAssertEqual(store(minute: 1000, on: F.monday, shownDay: F.monday).state.thisDayTitle, "Wed 11 Nov only",
                       "nor today once the item is over")
        XCTAssertEqual(store(minute: 900, on: F.monday, shownDay: F.monday).state.thisDayTitle, "Mon 9 Nov only")
    }

    /// Spec G5 "More G5 edges": a shown day that is a school holiday (the item skips them) moves on to
    /// the item's next day.
    func testAShownHolidayMovesThisDayToTheNextDay() async {
        let wed18 = Day(year: 2026, month: 11, day: 18)
        let store = store(on: tuesday, shownDay: wed18, holidays: { _ in [wed18] })
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.thisDayTitle, "Mon 23 Nov only")
    }

    /// Spec G5 "More G5 edges": the middle tab skips a skipped day and, for an item that skips school
    /// holidays, a holiday; holidays are read for the next year too when the window crosses it.
    func testTheMiddleTabSkipsSkippedDaysAndHolidays() async {
        func middle(_ item: ScheduleItem, on day: Day, holidays: @escaping @Sendable (Int) -> [Day]) async -> [String] {
            let store = store(item, on: day, holidays: holidays)
            await store.send(.task)
            await store.receive(\.loaded)
            await store.send(.scopeTapped(.allDays))
            await store.send(.binding(.set(\.form.end, 1020)))
            await store.send(.saveTapped)
            return store.state.fromWhenTabs.map(\.1)
        }
        let wed11 = Day(year: 2026, month: 11, day: 11)
        var skipped = swim
        skipped.skippedDays = [wed11]
        let afterSkip = await middle(skipped, on: tuesday) { _ in [] }
        XCTAssertEqual(afterSkip, ["Today", "Mon 16 Nov", "Date"], "Wed 11 is skipped")
        let afterHoliday = await middle(swim, on: tuesday) { _ in [wed11] }
        XCTAssertEqual(afterHoliday, ["Today", "Mon 16 Nov", "Date"], "Wed 11 is a holiday")
        var onHolidays = swim
        onHolidays.skipsHolidays = false
        let onHoliday = await middle(onHolidays, on: tuesday) { _ in [wed11] }
        XCTAssertEqual(onHoliday, ["Today", "Tomorrow", "Date"], "it runs on holidays")

        // Tue 29 Dec: Wed 30 Dec (2026) and Mon 4 Jan (2027) are holidays.
        let newYear = await middle(swim, on: Day(year: 2026, month: 12, day: 29)) { year in
            year == 2026 ? [Day(year: 2026, month: 12, day: 30)] : year == 2027 ? [Day(year: 2027, month: 1, day: 4)] : []
        }
        XCTAssertEqual(newYear, ["Today", "Wed 6 Jan", "Date"], "January's holidays are read too")
    }

    /// Spec G5 (#250): G5 opens on the moved This day, not the raw shown day. Thu 12 has no swimming,
    /// so This day is Mon 16 and G5 opens on Date 16; Tue 10 (today, none) moves to Wed 11, the middle
    /// tab.
    func testFromWhenOpensOnTheMovedThisDay() async {
        func open(_ shown: Day) async -> (ItemEditorFeature.FromWhen?, Day) {
            let store = store(on: tuesday, shownDay: shown)
            await store.send(.task)
            await store.receive(\.loaded)
            await store.send(.scopeTapped(.allDays))
            await store.send(.binding(.set(\.form.end, 1020)))
            await store.send(.saveTapped)
            return (store.state.fromWhen, store.state.splitDay)
        }
        let thursday = await open(Day(year: 2026, month: 11, day: 12))
        XCTAssertEqual(thursday.0, .date)
        XCTAssertEqual(thursday.1, Day(year: 2026, month: 11, day: 16))
        let today = await open(tuesday)
        XCTAssertEqual(today.0, .next)
        XCTAssertEqual(today.1, Day(year: 2026, month: 11, day: 11))
    }

    /// Spec G5: a This day change from G1 saves on the day shown there.
    func testThisDaySavesOnTheDayG1Showed() async {
        let saved = LockIsolated<[[ScheduleItem]]>([])
        let wed18 = Day(year: 2026, month: 11, day: 18)
        let store = store(on: tuesday, shownDay: wed18, saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.binding(.set(\.form.end, 1020)))
        await store.send(.saveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(saved.value.last?.first?.dayChanges, [DayChange(day: wed18, end: 1020)])
    }

    /// Remove every week from G1 on a later day ends the series from that day.
    func testRemoveFromTheClockEndsTheSeriesFromTheShownDay() async {
        let saved = LockIsolated<[[ScheduleItem]]>([])
        let store = store(on: tuesday, shownDay: Day(year: 2026, month: 11, day: 18), saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.scopeTapped(.allDays))
        await store.send(.removeSeriesTapped)
        XCTAssertEqual(store.state.confirmMessage,
                       "It leaves Kid A's clock from Wed 18 Nov. Days before stay in the diary.")
        await store.send(.confirmAccepted)
        await store.receive(\.saved)
        XCTAssertEqual(saved.value.last?.first?.recurrence,
                       .weekly([.monday, .wednesday], from: Day(year: 2026, month: 11, day: 1),
                               until: Day(year: 2026, month: 11, day: 17)))
    }

    func testFromWhenListsChangedDaysThatNoLongerFit() async {
        var changed = swim
        changed.dayChanges = [DayChange(day: Day(year: 2026, month: 11, day: 16), start: 960)]
        let store = store(changed)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.scopeTapped(.allDays))
        await store.send(.dayToggled(.monday))
        await store.send(.saveTapped)
        XCTAssertEqual(store.state.fromWhenCaption, "16 Nov was changed and no longer fits. It’ll be removed.")
        await store.send(.fromWhenCancelTapped)
        XCTAssertNil(store.state.fromWhen)
    }

    func testRemoveAsksThenEndsSeriesAndFinishes() async {
        let saved = LockIsolated<[[ScheduleItem]]>([])
        let store = store(saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.scopeTapped(.allDays))
        await store.send(.removeSeriesTapped)
        XCTAssertEqual(store.state.confirmTitle, "Remove Swimming every week?")
        XCTAssertEqual(store.state.confirmMessage,
                       "It leaves Kid A's clock from Mon 9 Nov. Days before stay in the diary.")
        await store.send(.confirmAccepted)
        await store.receive(\.saved)
        await store.receive(\.delegate.finished)
        XCTAssertEqual(saved.value.last?.first?.recurrence,
                       .weekly([.monday, .wednesday], from: Day(year: 2026, month: 11, day: 1),
                               until: Day(year: 2026, month: 11, day: 8)))
    }

    func testSideColumnTitleAndNoPreview() {
        let store = store()
        XCTAssertTrue(store.state.isEditingWeekly)
        XCTAssertEqual(store.state.everyTitle, "Every Mon and Wed")
        XCTAssertNil(store.state.preview, "the every-week side column shows no preview")
    }

    func testRepeatCannotSwitchToJustOnce() async {
        let store = store()
        await store.send(.repeatChanged(.once))
        XCTAssertEqual(store.state.form.repeats, .weekly)
    }
}
