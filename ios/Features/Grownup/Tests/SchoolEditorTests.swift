import ComposableArchitecture
import Domain
import Foundation
import Grownup
import HolidayProvider
import ScheduleStore
import XCTest

/// G4 · Edit School (first part), with the seed family (made-up school and times).
@MainActor
final class SchoolEditorTests: XCTestCase {
    private typealias F = Fixture
    /// Not a public holiday (9 Nov 2026 is Deepavali observed).
    private let tuesday = Day(year: 2026, month: 11, day: 10)

    private func day(_ number: Int) -> Day { Day(year: 2026, month: 11, day: number) }

    private func store(savedKids: LockIsolated<[Kid]>, savedRoutines: LockIsolated<[Routine]>,
                       directoryID: String? = nil, schools: [SchoolEntry] = [], today: Day? = nil,
                       nowMinute: Int = 600, shownDay: Day? = nil, holidays: [Holiday] = [])
        -> TestStoreOf<SchoolEditorFeature> {
        var kidA = SeedData.kidA
        kidA.school?.arriveBy = 450
        kidA.school?.latest = 460
        kidA.school?.directoryID = directoryID
        let kids = [kidA, SeedData.kidB]
        let state = SchoolEditorFeature.State(kid: kidA.id, today: today ?? tuesday, nowMinute: nowMinute,
                                              shownDay: shownDay, calendar: F.calendar)
        let store = TestStore(initialState: state) {
            SchoolEditorFeature()
        } withDependencies: {
            $0.calendar = F.calendar
            $0.holidays.holidays = { _ in holidays }
            $0.scheduleStore.load = { ScheduleSnapshot(kids: kids, routines: SeedData.routines, items: []) }
            $0.scheduleStore.saveKid = { kid in savedKids.withValue { $0.append(kid) } }
            $0.scheduleStore.saveRoutine = { routine in savedRoutines.withValue { $0.append(routine) } }
            $0.schoolDirectory.calendar = { _, _ in .none }
            $0.schoolDirectory.schools = { schools }
            $0.uuid = .incrementing
        }
        store.exhaustivity = .off
        return store
    }

    /// Spec G4 Terms (layout v63): a school the list knows shows its terms as text, with no MOE
    /// switch; a school typed by hand, or one whose terms the list doesn't know, keeps the switch.
    func testTheMoeSwitchShowsOnlyForASchoolTheListDoesNotKnow() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        func entry(_ follows: Bool?) -> SchoolEntry {
            SchoolEntry(id: "example-primary", name: "Example Primary School", kind: .moe(.primary), area: "Example Town",
                        hasPrimary: true, followsMoeTerms: follows, hours: nil, breakCount: 0, searchKeys: [])
        }
        for (directoryID, schools, shows) in [(String?.none, [SchoolEntry](), true),
                                              ("example-primary", [entry(true)], false),
                                              ("example-primary", [entry(false)], false),
                                              ("example-primary", [entry(nil)], true)] {
            let store = store(savedKids: kids, savedRoutines: routines, directoryID: directoryID, schools: schools)
            await store.send(.task)
            await store.receive(\.loaded)
            await store.receive(\.schoolYearLoaded)
            XCTAssertEqual(store.state.showsMoeCheck, shows, "\(String(describing: directoryID)) \(schools.map(\.followsMoeTerms))")
        }
    }

    func testMovingTheStartMovesArriveByAndKeepsTheGrace() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.everyTitle, "Every school day")
        XCTAssertFalse(store.state.canSave, "nothing changed yet")
        await store.send(.startPicked(tuesday.date(minute: 480, calendar: F.calendar)))
        XCTAssertEqual(store.state.school?.start, 480)
        XCTAssertEqual(store.state.arriveBy, 480)
        XCTAssertEqual(store.state.latest, 490)
        await store.send(.endPicked(tuesday.date(minute: 870, calendar: F.calendar)))
        await store.send(.saveTapped)
        XCTAssertEqual(store.state.fromWhen, .today, "All days asks from when first")
        await store.send(.fromWhenSaveTapped)
        await store.receive(\.saved)
        await store.receive(\.delegate.finished)
        XCTAssertEqual(kids.value.last?.school?.start, 480)
        XCTAssertEqual(kids.value.last?.school?.end, 870)
        // The weekday template from today: School's slice on the new times, its neighbours following.
        let school = routines.value.last?.blocks.first { $0.kind == .school }
        XCTAssertEqual(routines.value.last?.from, tuesday)
        XCTAssertEqual(school?.start, 480)
        XCTAssertEqual(school?.end, 870)
    }

    func testDaysArriveByMedalAndGoing() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.dayToggled(.friday))
        XCTAssertEqual(store.state.everyTitle, "Mon · Tue · Wed · Thu")
        await store.send(.arriveByPicked(tuesday.date(minute: 440, calendar: F.calendar)))
        XCTAssertEqual(store.state.latest, 450, "Latest keeps the 10-minute grace")
        await store.send(.medalToggled)
        XCTAssertFalse(store.state.medal)
        await store.send(.goingTapped)
        await store.receive(\.delegate.openBuses)
    }

    /// Board G4 Bring (F2): up to four things, named as the thing; Cancel puts them back.
    func testBringPicksAndCancels() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.bringRowTapped)
        await store.send(.bringToggled(.libraryBag))
        await store.send(.bringToggled(.waterBottle))
        XCTAssertEqual(store.state.bringText, "Library bag · Water bottle")
        await store.send(.bringDoneTapped)
        await store.send(.bringRowTapped)
        await store.send(.bringToggled(.waterBottle))
        await store.send(.bringClosed)
        XCTAssertEqual(store.state.bringText, "Library bag · Water bottle", "Cancel puts the list back")
        await store.send(.saveTapped)
        await store.send(.fromWhenSaveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(kids.value.last?.school?.bring?.map(\.picture), ["libraryBag", "waterBottle"])
    }

    /// Spec "Edit scope": This day keeps the school record and saves only the day's own template.
    func testThisDayMovesOnlyThatDay() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.scopeTapped(.thisDay))
        await store.send(.endPicked(tuesday.date(minute: 780, calendar: F.calendar)))
        await store.send(.saveTapped)
        await store.receive(\.saved)
        XCTAssertTrue(kids.value.isEmpty, "the school record stays")
        XCTAssertEqual(routines.value.last?.onlyOn, tuesday)
        XCTAssertEqual(routines.value.last?.blocks.first { $0.kind == .school }?.end, 780)
    }

    /// Spec "E5 School rule": This day shows "{Day d Mon} only" and skips School on that day (a sick
    /// day), saved at once; "Bring back" undoes it.
    func testThisDaySkipsSchoolAndBringsItBack() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.scopeTapped(.thisDay))
        XCTAssertEqual(store.state.thisDayTitle, "Tue 10 Nov only")
        XCTAssertEqual(store.state.skipTitle, "Skip this day")
        await store.send(.skipDayTapped)
        await store.receive(\.daySkipSaved)
        XCTAssertEqual(routines.value.last?.onlyOn, tuesday)
        XCTAssertEqual(routines.value.last?.blocks.first { $0.kind == .school }?.isSkipped, true)
        XCTAssertTrue(store.state.isDaySkipped)
        await store.send(.skipDayTapped)
        await store.receive(\.daySkipSaved)
        XCTAssertEqual(routines.value.last?.blocks.first { $0.kind == .school }?.isSkipped, false)
        XCTAssertTrue(kids.value.isEmpty, "the school record stays")
    }

    // MARK: G5 "Change from when?" (spec G5 "Which screens and days")

    /// An All days save asks G5 first and saves nothing until its Save; Cancel keeps the form.
    /// "Tomorrow" is Wed 11 Nov, a school day; the weekday template changes from the day picked.
    func testAllDaysAsksFromWhenThenSavesFromThatDay() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.receive(\.familyLoaded)
        await store.send(.endPicked(tuesday.date(minute: 870, calendar: F.calendar)))
        await store.send(.saveTapped)
        XCTAssertEqual(store.state.fromWhen, .today, "from Settings G5 opens on Today")
        XCTAssertEqual(store.state.fromWhenTabs.map(\.1), ["Today", "Tomorrow", "Date"])
        XCTAssertTrue(kids.value.isEmpty && routines.value.isEmpty, "nothing is saved before G5's Save")
        await store.send(.fromWhenCancelTapped)
        XCTAssertNil(store.state.fromWhen)
        XCTAssertEqual(store.state.school?.end, 870, "Cancel keeps the change on the form")

        await store.send(.saveTapped)
        await store.send(.fromWhenPicked(.next))
        XCTAssertEqual(store.state.splitDay, day(11))
        await store.send(.fromWhenSaveTapped)
        await store.receive(\.saved)
        XCTAssertNil(store.state.fromWhen)
        XCTAssertEqual(routines.value.last?.from, day(11))
        XCTAssertEqual(routines.value.last?.dayType, .weekday)
        XCTAssertEqual(routines.value.last?.blocks.first { $0.kind == .school }?.end, 870)
        XCTAssertEqual(kids.value.last?.school?.end, 870, "the school record has no date: it changes now, as on G1")
    }

    /// G5's Date: a weekend date still makes the weekday template from that day; never before today.
    func testFromWhenDateMakesTheWeekdayTemplateFromThatDay() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.endPicked(tuesday.date(minute: 870, calendar: F.calendar)))
        await store.send(.saveTapped)
        await store.send(.fromWhenDatePicked(day(2).date(calendar: F.calendar)))
        XCTAssertEqual(store.state.splitDay, tuesday, "never before today")
        await store.send(.fromWhenDatePicked(day(21).date(calendar: F.calendar)))
        XCTAssertEqual(store.state.fromWhenDateLabel, "21 Nov")
        await store.send(.fromWhenSaveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(routines.value.last?.from, day(21))
        XCTAssertEqual(routines.value.last?.dayType, .weekday)
        XCTAssertEqual(routines.value.last?.blocks.first { $0.kind == .school }?.start, 450)
    }

    /// Spec G5: G4 opened from G1 on a later day opens the card on that day: the middle tab when it is
    /// School's next day, else Date with that day; from today, on Today.
    func testFromWhenOpensOnTheDayG1Showed() async {
        func opening(_ shown: Day) async -> (FromWhenTabs.Choice?, Day) {
            let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
            let store = store(savedKids: kids, savedRoutines: routines, shownDay: shown)
            await store.send(.task)
            await store.receive(\.loaded)
            await store.send(.endPicked(tuesday.date(minute: 870, calendar: F.calendar)))
            await store.send(.saveTapped)
            return (store.state.fromWhen, store.state.splitDay)
        }
        let later = await opening(day(18))
        XCTAssertEqual(later.0, .date)
        XCTAssertEqual(later.1, day(18))
        let next = await opening(day(11))
        XCTAssertEqual(next.0, .next)
        XCTAssertEqual(next.1, day(11))
        let today = await opening(tuesday)
        XCTAssertEqual(today.0, .today)
    }

    /// G5's middle day is School's next day after today: one of its days (as changed on the form) that
    /// is not a day off.
    func testTheMiddleTabIsSchoolsNextDay() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let friday = store(savedKids: kids, savedRoutines: routines, today: day(13))
        await friday.send(.task)
        await friday.receive(\.loaded)
        await friday.receive(\.familyLoaded)
        await friday.send(.endPicked(day(13).date(minute: 870, calendar: F.calendar)))
        await friday.send(.saveTapped)
        XCTAssertEqual(friday.state.fromWhenTabs.map(\.1), ["Today", "Mon 16 Nov", "Date"], "the weekend is skipped")
        await friday.send(.fromWhenCancelTapped)
        await friday.send(.dayToggled(.monday))
        await friday.send(.saveTapped)
        XCTAssertEqual(friday.state.fromWhenTabs.map(\.1), ["Today", "Tue 17 Nov", "Date"], "the changed days")

        let holiday = store(savedKids: kids, savedRoutines: routines, today: day(13),
                            holidays: [Holiday(day: day(16), name: "Example Day")])
        await holiday.send(.task)
        await holiday.receive(\.loaded)
        await holiday.receive(\.familyLoaded)
        await holiday.send(.endPicked(day(13).date(minute: 870, calendar: F.calendar)))
        await holiday.send(.saveTapped)
        XCTAssertEqual(holiday.state.fromWhenTabs.map(\.1), ["Today", "Tue 17 Nov", "Date"], "a day off is skipped")
    }

    /// Spec G5: from G1 "This day" is the day shown there; from the List or Settings it is School's next
    /// day (today until School is over, then the next school day).
    func testThisDayIsTheShownDayElseSchoolsNextDay() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        func thisDay(today: Day? = nil, nowMinute: Int = 600, shownDay: Day? = nil) async -> String {
            let store = store(savedKids: kids, savedRoutines: routines, today: today, nowMinute: nowMinute,
                              shownDay: shownDay)
            await store.send(.task)
            await store.receive(\.loaded)
            await store.receive(\.familyLoaded)
            return store.state.thisDayTitle
        }
        let shown = await thisDay(shownDay: day(12))
        XCTAssertEqual(shown, "Thu 12 Nov only")
        let beforeSchoolEnds = await thisDay(nowMinute: 899)
        XCTAssertEqual(beforeSchoolEnds, "Tue 10 Nov only")
        let afterSchool = await thisDay(nowMinute: 900)
        XCTAssertEqual(afterSchool, "Wed 11 Nov only")
        let weekend = await thisDay(today: day(14))
        XCTAssertEqual(weekend, "Mon 16 Nov only")
    }

    /// From Settings on a Saturday, This day's skip lands on Monday and stays there once skipped.
    func testThisDaySkipFromSettingsSkipsSchoolsNextDay() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines, today: day(14))
        await store.send(.task)
        await store.receive(\.loaded)
        await store.receive(\.familyLoaded)
        await store.send(.scopeTapped(.thisDay))
        XCTAssertTrue(store.state.canSkipDay)
        await store.send(.skipDayTapped)
        await store.receive(\.daySkipSaved)
        XCTAssertEqual(routines.value.last?.onlyOn, day(16))
        XCTAssertEqual(store.state.thisDayTitle, "Mon 16 Nov only", "a skip does not move This day")
        XCTAssertEqual(store.state.skipTitle, "Bring back this day")
    }
}
