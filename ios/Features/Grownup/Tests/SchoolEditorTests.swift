import ComposableArchitecture
import Domain
import Foundation
import Grownup
import HolidayProvider
import Localization
import ScheduleStore
import XCTest

/// G4 · Edit School (first part), with the seed family (made-up school and times).
@MainActor
final class SchoolEditorTests: XCTestCase {
    private typealias F = Fixture
    /// Not a public holiday (9 Nov 2026 is Deepavali observed).
    private let tuesday = Day(year: 2026, month: 11, day: 10)

    private func day(_ number: Int) -> Day { Day(year: 2026, month: 11, day: number) }

    /// A waiting hours change from Wed 18 Nov: 8:30 am – 2:00 pm, Arrive by 8:30, Latest 8:40.
    private var waitingDay: Day { day(18) }
    private var waitingSchool: School {
        var school = SeedData.kidA.school!
        school.start = 510
        school.end = 840
        school.arriveBy = 510
        school.latest = 520
        return school
    }
    /// Kid A's weekday version on the waiting day with another edit (Dinner at 6:45 pm).
    private var dinnerVersion: Routine {
        var version = SeedData.routines.first { $0.kid == SeedData.kidA.id && $0.dayType == .weekday }!
        version.from = waitingDay
        if let index = version.blocks.firstIndex(where: { $0.kind == .dinner }) {
            version.blocks[index - 1].end = 1125
            version.blocks[index].start = 1125
        }
        return version
    }

    private func store(savedKids: LockIsolated<[Kid]>, savedRoutines: LockIsolated<[Routine]>,
                       routines extra: [Routine] = [],
                       directoryID: String? = nil, schools: [SchoolEntry] = [], today: Day? = nil,
                       nowMinute: Int = 600, shownDay: Day? = nil, holidays: [Holiday] = [],
                       waits: Bool = false, editsWaiting: Bool = false)
        -> TestStoreOf<SchoolEditorFeature> {
        var kidA = SeedData.kidA
        kidA.school?.arriveBy = 450
        kidA.school?.latest = 460
        kidA.school?.directoryID = directoryID
        let routines = SeedData.routines + extra
        // The waiting change is only on the kid: it writes no template (spec #255).
        if waits { kidA.pendingHours = PendingHours(school: waitingSchool, from: waitingDay, medal: false) }
        let kids = [kidA, SeedData.kidB]
        let state = SchoolEditorFeature.State(kid: kidA.id, today: today ?? tuesday, nowMinute: nowMinute,
                                              shownDay: shownDay, editsWaiting: editsWaiting, calendar: F.calendar)
        let store = TestStore(initialState: state) {
            SchoolEditorFeature()
        } withDependencies: {
            $0.calendar = F.calendar
            $0.holidays.holidays = { year in holidays.filter { $0.day.year == year } }
            $0.scheduleStore.load = { ScheduleSnapshot(kids: kids, routines: routines, items: [], missions: SeedData.missions) }
            $0.scheduleStore.saveKid = { kid in savedKids.withValue { $0.append(kid) } }
            $0.scheduleStore.saveRoutine = { routine in savedRoutines.withValue { $0.append(routine) } }
            $0.schoolDirectory.calendar = { _, _ in .none }
            $0.schoolDirectory.schools = { schools }
            $0.uuid = .incrementing
        }
        store.exhaustivity = .off
        return store
    }

    /// Spec G4 Terms: a school the list knows shows its terms as text, with no MOE
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
        XCTAssertTrue(store.state.isDayOn(.friday))
        await store.send(.dayToggled(.friday))
        XCTAssertEqual(store.state.everyTitle, "Mon · Tue · Wed · Thu")
        XCTAssertFalse(store.state.isDayOn(.friday), "the Days row's Fri chip is off")
        XCTAssertTrue(store.state.isDayOn(.monday))
        await store.send(.arriveByPicked(tuesday.date(minute: 440, calendar: F.calendar)))
        XCTAssertEqual(store.state.latest, 450, "Latest keeps the 10-minute grace")
        XCTAssertTrue(store.state.canSwitchMedal, "School has a trip")
        await store.send(.medalToggled)
        XCTAssertFalse(store.state.medal)
        await store.send(.goingTapped)
        await store.receive(\.delegate.openBuses)
    }

    /// Design 2026-11-22: the medal lives on School's trip, so without a way to school the Medal
    /// switch is off (40 %) and a tap changes nothing.
    func testMedalSwitchNeedsSchoolsTrip() async {
        var noTrip = SeedData.routines.first { $0.kid == SeedData.kidA.id && $0.dayType == .weekday }!
        if let index = noTrip.blocks.firstIndex(where: { $0.kind == .school }) { noTrip.blocks[index].trip = nil }
        noTrip.from = tuesday
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines, routines: [noTrip])
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertFalse(store.state.canSwitchMedal)
        XCTAssertFalse(store.state.medalIsOn, "no trip, no medal: the switch shows off, as on the item editor")
        let medal = store.state.medal
        await store.send(.medalToggled)
        XCTAssertEqual(store.state.medal, medal, "an off switch changes nothing")
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

    /// Spec G2 "School is an event": This day shows "{Day d Mon} only" and skips School on that day (a sick
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
        // Spec G5 "What Settings shows meanwhile", #255: today's hours stay until that day; the new
        // ones wait on the kid and no template copies them (dates read them from their day).
        XCTAssertEqual(kids.value.last?.school?.end, 900, "today's hours stay in force")
        XCTAssertEqual(kids.value.last?.pendingHours?.from, day(11))
        XCTAssertEqual(kids.value.last?.pendingHours?.school.end, 870)
        XCTAssertNil(kids.value.last?.pendingHours?.medal, "the medal did not change")
        XCTAssertEqual(routines.value, [])
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
        XCTAssertEqual(kids.value.last?.pendingHours?.from, day(21), "a weekend date waits for that day")
        XCTAssertEqual(kids.value.last?.pendingHours?.school.start, 450)
        XCTAssertEqual(routines.value, [])
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
        // Spec G5 "More G5 edges": a carried day that has passed, is over or has no School moves on.
        let past = await thisDay(shownDay: day(9))
        XCTAssertEqual(past, "Tue 10 Nov only", "a day before today: School's next day")
        let over = await thisDay(nowMinute: 900, shownDay: tuesday)
        XCTAssertEqual(over, "Wed 11 Nov only", "today once School is over")
        let saturday = await thisDay(shownDay: day(14))
        XCTAssertEqual(saturday, "Mon 16 Nov only", "no School on the shown day: the next school day after it")
    }

    /// Spec G5 (#250): G5 opens on the moved This day: a carried Saturday without School opens on
    /// Monday (Date 16, since the middle day is Wed 11).
    func testFromWhenOpensOnTheMovedThisDay() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines, shownDay: day(14))
        await store.send(.task)
        await store.receive(\.loaded)
        await store.receive(\.familyLoaded)
        await store.send(.endPicked(tuesday.date(minute: 870, calendar: F.calendar)))
        await store.send(.saveTapped)
        XCTAssertEqual(store.state.fromWhen, .date)
        XCTAssertEqual(store.state.splitDay, day(16))
    }

    /// A carried day that is a day off (a public holiday) moves to the next school day.
    func testAShownDayOffMovesThisDayToTheNextSchoolDay() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines, shownDay: day(16),
                          holidays: [Holiday(day: day(16), name: "Example Day")])
        await store.send(.task)
        await store.receive(\.loaded)
        await store.receive(\.familyLoaded)
        XCTAssertEqual(store.state.thisDayTitle, "Tue 17 Nov only")
    }

    /// Spec G5 "More G5 edges": the middle tab reads the next year's holidays when the window crosses it.
    func testTheMiddleTabReadsNextYearsHolidays() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let dec29 = Day(year: 2026, month: 12, day: 29)
        let holidays = [Day(year: 2026, month: 12, day: 30), Day(year: 2026, month: 12, day: 31),
                        Day(year: 2027, month: 1, day: 1), Day(year: 2027, month: 1, day: 4)]
            .map { Holiday(day: $0, name: "Example Day") }
        let store = store(savedKids: kids, savedRoutines: routines, today: dec29, holidays: holidays)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.receive(\.familyLoaded)
        await store.send(.endPicked(dec29.date(minute: 870, calendar: F.calendar)))
        await store.send(.saveTapped)
        XCTAssertEqual(store.state.fromWhenTabs.map(\.1), ["Today", "Tue 5 Jan", "Date"])
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

    /// All days builds on the weekday template, never on a day's own one: a This day skip today does
    /// not reach every school day.
    func testAllDaysIsBuiltOnTheWeekdayTemplateNotTheDaysOwn() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.receive(\.familyLoaded)
        await store.send(.scopeTapped(.thisDay))
        await store.send(.skipDayTapped)
        await store.receive(\.daySkipSaved)
        XCTAssertEqual(routines.value.last?.onlyOn, tuesday)
        await store.send(.scopeTapped(.allDays))
        await store.send(.endPicked(tuesday.date(minute: 870, calendar: F.calendar)))
        await store.send(.saveTapped)
        await store.send(.fromWhenSaveTapped)
        await store.receive(\.saved)
        XCTAssertNil(routines.value.last?.onlyOn)
        XCTAssertEqual(routines.value.last?.blocks.first { $0.kind == .school }?.isSkipped, false)
        XCTAssertEqual(routines.value.last?.blocks.first { $0.kind == .school }?.end, 870)
    }

    // MARK: The waiting hours change (spec G5 "What Settings shows meanwhile", #255)

    /// G4 opened any other way starts from today's whole record; the waiting change shows under When
    /// and its row turns this G4 to the waiting values, with "Cancel this change". No edits, no Save.
    func testTheWaitingRowOpensTheWaitingHours() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines, waits: true)
        XCTAssertNil(store.state.school, "no form before the store answers")
        XCTAssertNil(store.state.waitingLine)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.startLabel, "7:30 am", "today's hours")
        XCTAssertEqual(store.state.waitingLine, "From 18 Nov · 8:30 am – 2:00 pm")
        XCTAssertNil(store.state.cancelChangeTitle)
        XCTAssertTrue(store.state.medal)

        await store.send(.waitingRowTapped)
        XCTAssertTrue(store.state.editsWaiting)
        XCTAssertEqual(store.state.startLabel, "8:30 am")
        XCTAssertEqual(store.state.endLabel, "2:00 pm")
        XCTAssertEqual(store.state.arriveByLabel, "8:30 am")
        XCTAssertFalse(store.state.medal, "the waiting change's medal")
        XCTAssertNil(store.state.waitingLine)
        XCTAssertEqual(store.state.cancelChangeTitle, "Cancel this change")
        XCTAssertFalse(store.state.canSave, "nothing changed yet")
        await store.send(.saveTapped)
        XCTAssertNil(store.state.fromWhen)
    }

    /// Opened from its row (Settings), the form is the waiting change; a second save replaces it, G5
    /// asks again on its day, and still no template is written.
    func testSavingTheWaitingChangeAgainReplacesIt() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines, waits: true, editsWaiting: true)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.receive(\.familyLoaded)
        XCTAssertEqual(store.state.startLabel, "8:30 am")
        await store.send(.endPicked(tuesday.date(minute: 780, calendar: F.calendar)))
        await store.send(.saveTapped)
        XCTAssertEqual(store.state.fromWhen, .date, "G5 opens on the waiting day")
        XCTAssertEqual(store.state.splitDay, waitingDay)
        await store.send(.fromWhenSaveTapped)
        await store.receive(\.saved)
        await store.receive(\.delegate.finished)
        var replaced = waitingSchool
        replaced.end = 780
        XCTAssertEqual(kids.value.last?.school?.end, 900, "today's hours stay")
        XCTAssertEqual(kids.value.last?.pendingHours, PendingHours(school: replaced, from: waitingDay, medal: false))
        XCTAssertEqual(routines.value, [])
    }

    /// A second save from another day moves the waiting change there; nothing is left on the old day.
    func testSavingFromAnotherDayMovesTheWaitingChange() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines, waits: true, editsWaiting: true)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.medalToggled)
        await store.send(.saveTapped)
        await store.send(.fromWhenDatePicked(day(25).date(calendar: F.calendar)))
        await store.send(.fromWhenSaveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(kids.value.last?.pendingHours?.from, day(25))
        XCTAssertNil(kids.value.last?.pendingHours?.medal, "back on the template's medal")
        XCTAssertEqual(routines.value, [])
    }

    /// Spec G5: a save from "Today" while a change waits drops it; the template from today is written
    /// as any Today save, and that day's own version keeps its other edits (#255).
    func testASaveFromTodayDropsTheWaitingChange() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines, routines: [dinnerVersion], waits: true)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.endPicked(tuesday.date(minute: 870, calendar: F.calendar)))
        await store.send(.saveTapped)
        XCTAssertEqual(store.state.fromWhen, .today)
        await store.send(.fromWhenSaveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(kids.value.last?.school?.end, 870, "the record changes now")
        XCTAssertNil(kids.value.last?.pendingHours)
        // "From today" reaches the waiting day's version too (it follows the record): its Dinner stays.
        XCTAssertEqual(routines.value.map(\.from), [waitingDay, tuesday])
        XCTAssertEqual(routines.value.first?.blocks.first { $0.kind == .school }?.end, 870)
        XCTAssertEqual(routines.value.first?.blocks.first { $0.kind == .dinner }?.start, 1125)
    }

    /// A design answer to #255: a School save from today reaches later templates, a day's own ones
    /// included, that follow the old record; a day with its own School times keeps them.
    func testASaveFromTodayReachesLaterTemplates() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        var later = SeedData.routines.first { $0.kid == SeedData.kidA.id && $0.dayType == .weekday }!
        later.from = day(25)
        let skipped = Routine.day(day(20), kid: SeedData.kidA.id, dayType: .weekday, blocks: later.blocks)
        var lateStart = skipped
        lateStart.onlyOn = day(23)
        lateStart.from = day(23)
        if let index = lateStart.blocks.firstIndex(where: { $0.kind == .school }) {
            lateStart.blocks[index - 1].end = 540
            lateStart.blocks[index].start = 540
        }
        let store = store(savedKids: kids, savedRoutines: routines, routines: [later, skipped, lateStart])
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.endPicked(tuesday.date(minute: 870, calendar: F.calendar)))
        await store.send(.saveTapped)
        await store.send(.fromWhenSaveTapped)
        await store.receive(\.saved)
        let saved = routines.value
        XCTAssertEqual(saved.map { $0.onlyOn ?? $0.from }, [day(25), day(20), tuesday])
        XCTAssertEqual(saved.first?.blocks.first { $0.kind == .school }?.end, 870)
        XCTAssertEqual(saved[1].blocks.first { $0.kind == .school }?.end, 870)
        XCTAssertFalse(saved.contains { $0.onlyOn == day(23) }, "a late start of its own stays")
    }

    /// "Cancel this change" asks first ("Cancel the change from 18 Nov?"); the link alone and "Keep"
    /// save nothing.
    func testCancelThisChangeAsksFirst() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines, waits: true, editsWaiting: true)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.cancelChangeTapped)
        XCTAssertTrue(store.state.isConfirmingCancel)
        XCTAssertEqual(store.state.cancelConfirmTitle, "Cancel the change from 18 Nov?")
        XCTAssertEqual(store.state.cancelConfirmAction, "Cancel it")
        XCTAssertEqual(store.state.cancelConfirmKeep, "Keep")
        await store.send(.cancelKept)
        XCTAssertFalse(store.state.isConfirmingCancel)
        await store.finish()
        XCTAssertTrue(kids.value.isEmpty && routines.value.isEmpty, "nothing saved")
        XCTAssertTrue(store.state.editsWaiting, "still on the waiting change")
    }

    /// "Cancel it" removes only the waiting change: no template was written for it, so the waiting
    /// day's own version keeps its other edits; today's hours stay.
    func testCancelChangeRemovesOnlyTheWaitingChange() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines, routines: [dinnerVersion], waits: true,
                          editsWaiting: true)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.cancelChangeTapped)
        await store.send(.cancelConfirmed)
        await store.receive(\.saved)
        await store.receive(\.delegate.finished)
        XCTAssertNil(kids.value.last?.pendingHours)
        XCTAssertEqual(kids.value.last?.school?.start, 450, "today's hours stay")
        XCTAssertEqual(routines.value, [], "the waiting day's version (with its Dinner edit) is left as it is")
    }

    /// From its day the form's This day reads the waiting hours (the template by date); a skip there
    /// stores today's School, so a cancel returns that day to it.
    func testThisDayOnTheWaitingDayReadsTheWaitingHours() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines, shownDay: waitingDay, waits: true)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.scopeTapped(.thisDay))
        await store.send(.skipDayTapped)
        await store.receive(\.daySkipSaved)
        let school = routines.value.last?.blocks.first { $0.kind == .school }
        XCTAssertEqual(routines.value.last?.onlyOn, waitingDay)
        XCTAssertEqual(school?.start, 450, "the skip stores today's School, never a copy of the waiting one")
        XCTAssertEqual(school?.isSkipped, true)
        XCTAssertTrue(store.state.isDaySkipped)
        XCTAssertEqual(store.state.skipTitle, "Bring back this day")
    }

    /// Opened on a waiting change that is gone (cancelled elsewhere): today's hours, nothing to cancel.
    func testOpenedOnAWaitingChangeThatIsGoneShowsTodaysHours() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines, editsWaiting: true)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertFalse(store.state.editsWaiting)
        XCTAssertEqual(store.state.startLabel, "7:30 am")
        XCTAssertNil(store.state.cancelChangeTitle)
        await store.send(.cancelChangeTapped)
        XCTAssertFalse(store.state.isConfirmingCancel)
        XCTAssertTrue(kids.value.isEmpty)
    }

    /// Views hold no values: the rows' labels, the scope tabs, Save and the Bring card's words come
    /// from State, through the injected localizer; before the kid loads no Days chip is on.
    func testTheWordsComeFromState() {
        let state = SchoolEditorFeature.State(kid: SeedData.kidA.id, today: tuesday, calendar: F.calendar)
        XCTAssertEqual(state.scopeTabs.map(\.0), [.thisDay, .allDays])
        XCTAssertEqual(state.scopeTabs.map(\.1) + [state.saveTitle, state.schoolLabel, state.whenLabel, state.daysLabel,
                        state.arriveByRowLabel, state.latestWord, state.termsLabel, state.goingLabel,
                        state.bringLabel, state.beforeLabel, state.backLabel, state.bundlesCaption, state.takesLabel,
                        state.medalLabel, state.nothingText, state.bringDoneTitle,
                        state.bringCancelTitle, state.bringMoreTitle],
                       ["This day", "All days", "Save changes", "School", "When", "Days", "Arrive", "latest", "Terms",
                        "Going", "Bring", "Before", "Back", "Bundles", "Takes", "Medal", "Nothing", "Done", "Cancel", "More"])
        XCTAssertFalse(Weekday.allCases.contains { state.isDayOn($0) })
        let keys = withDependencies { $0.localizer = .keys } operation: {
            SchoolEditorFeature.State(kid: SeedData.kidA.id, today: tuesday, calendar: F.calendar)
        }
        XCTAssertEqual(keys.scopeTabs.map(\.1) + [keys.saveTitle, keys.schoolLabel, keys.whenLabel, keys.daysLabel,
                       keys.arriveByRowLabel, keys.latestWord, keys.termsLabel, keys.goingLabel,
                       keys.bringLabel, keys.beforeLabel, keys.backLabel, keys.bundlesCaption, keys.takesLabel,
                       keys.medalLabel, keys.nothingText, keys.bringDoneTitle,
                       keys.bringCancelTitle, keys.bringMoreTitle],
                       ["editor.scope.this_day", "editor.scope.all_days", "editor.primary.save", "settings.school",
                        "editor.row.when", "editor.row.days", "s2.arrive_by", "s2.latest", "settings.terms",
                        "going.label", "before.bring", "editor.row.before", "editor.row.back", "before.bundles",
                        "back.takes", "editor.row.medal", "editor.row.nothing", "c5.done",
                        "card.cancel", "picker.more"])
    }

    /// Issue 024 (board G4, F2, F7): School's Before card picks the kid's bundles with its Bring; Back
    /// picks the way home; Cancel puts the lists back; Save keeps them on the school record.
    func testBeforeAndBackOnSchool() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines)
        await store.send(.task)
        await store.receive(\.loaded)
        let morning = MissionBundle.morningID(for: SeedData.kidA.id)
        XCTAssertEqual(store.state.beforeText, "Morning routine", "the seed's School")
        XCTAssertTrue(store.state.showsBack, "nothing follows School")
        await store.send(.bringRowTapped)
        await store.send(.bundleToggled(morning))
        await store.send(.bringClosed)
        XCTAssertEqual(store.state.lists.before, [morning], "Cancel puts the bundle back")
        await store.send(.backRowTapped)
        await store.send(.wayHomePicked("bus"))
        await store.send(.homeAfterStepped(1))
        await store.send(.backDoneTapped)
        XCTAssertEqual(store.state.backText, "Bus · 5 min")
        await store.send(.saveTapped)
        await store.send(.fromWhenSaveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(kids.value.last?.school?.lists?.wayHome, .bus)
        XCTAssertEqual(kids.value.last?.school?.lists?.homeAfter, 5)
    }
}
