import AppSettings
import BusClient
import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import HolidayProvider
import Home
import KitArt
import Localization
import ScheduleStore
import SchoolDirectory
import XCTest

@MainActor
final class HomeFeatureTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return calendar
    }()
    private let tuesday = Day(year: 2026, month: 11, day: 10)
    private let wednesday = Day(year: 2026, month: 11, day: 11)
    private let saturday = Day(year: 2026, month: 11, day: 14)

    private func snapshot(kids: [Kid] = SeedData.kids) -> ScheduleSnapshot {
        ScheduleSnapshot(kids: kids, routines: SeedData.routines,
                         items: SeedData.items(today: tuesday, calendar: calendar), missions: SeedData.missions)
    }

    private func store(on day: Day, minute: Int, snapshot: ScheduleSnapshot? = nil,
                       holidays: [Holiday] = [], schoolClosed: Set<Day> = [],
                       breaks: [Day: String] = [:]) -> TestStoreOf<HomeFeature> {
        let snapshot = snapshot ?? self.snapshot()
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: { [calendar] in
            $0.calendar = calendar
            $0.date.now = day.date(minute: minute, calendar: calendar)
            $0.scheduleStore.load = { snapshot }
            $0.holidays.holidays = { _ in holidays }
            $0.schoolDirectory.calendar = { _, _ in SchoolCalendar(closed: schoolClosed.union(breaks.keys), breaks: breaks) }
            $0.bus.arrivals = { _ in
                [BusArrival(service: "1", minutes: 4, type: .single), BusArrival(service: "1", minutes: 28, type: .double)]
            }
        }
        store.exhaustivity = .off
        return store
    }

    /// Spec G5 / #255: a School hours change waiting from Wednesday. On Tuesday today's clock keeps
    /// today's hours and tomorrow reads the waiting ones; nothing is written yet.
    func testAWaitingHoursChangeReadsFromItsDay() async {
        var kidA = SeedData.kidA
        var later = kidA.school!
        later.end = 840
        kidA = kidA.savingSchool(later, from: wednesday, today: tuesday)
        let routines = LockIsolated<[Routine]>([])
        let store = store(on: tuesday, minute: 600, snapshot: snapshot(kids: [kidA, SeedData.kidB]))
        store.dependencies.scheduleStore.saveRoutine = { routine in routines.withValue { $0.append(routine) } }
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.days.first?.slots.first { $0.kind == .school }?.end, 900, "today's hours")
        XCTAssertEqual(store.state.days.first?.tomorrowSlots.first { $0.kind == .school }?.end, 840)
        XCTAssertEqual(routines.value, [])
    }

    /// On its day Home writes the waiting hours into that day's template version, then the record,
    /// once (routines first, the kid last).
    func testOnItsDayHomeWritesTheWaitingHoursThenTheRecord() async {
        var kidA = SeedData.kidA
        var later = kidA.school!
        later.end = 840
        kidA = kidA.savingSchool(later, from: wednesday, today: tuesday)
        let writes = LockIsolated<[String]>([]), routines = LockIsolated<[Routine]>([]), kids = LockIsolated<[Kid]>([])
        let store = store(on: wednesday, minute: 600, snapshot: snapshot(kids: [kidA, SeedData.kidB]))
        store.dependencies.scheduleStore.saveRoutine = { routine in
            routines.withValue { $0.append(routine) }
            writes.withValue { $0.append("routine") }
        }
        store.dependencies.scheduleStore.saveKid = { kid in
            kids.withValue { $0.append(kid) }
            writes.withValue { $0.append("kid") }
        }
        await store.send(.task)
        await store.receive(\.loaded)
        await store.receive(\.reload)
        await store.receive(\.loaded)
        XCTAssertEqual(writes.value, ["routine", "kid"])
        XCTAssertEqual(routines.value.first?.from, wednesday)
        XCTAssertEqual(routines.value.first?.dayType, .weekday)
        XCTAssertEqual(routines.value.first?.blocks.first { $0.kind == .school }?.end, 840)
        XCTAssertEqual(kids.value.first?.school, later)
        XCTAssertNil(kids.value.first?.pendingHours)
    }

    /// Review of #257: when a template save fails on the day, the record is not written, so the change
    /// still waits (read by date) instead of leaving a template on the old slot for good.
    func testOnItsDayAFailedTemplateSaveLeavesTheRecordWaiting() async {
        struct SaveFailed: Error {}
        var kidA = SeedData.kidA
        var later = kidA.school!
        later.end = 840
        kidA = kidA.savingSchool(later, from: wednesday, today: tuesday)
        let kids = LockIsolated<[Kid]>([])
        let store = store(on: wednesday, minute: 600, snapshot: snapshot(kids: [kidA, SeedData.kidB]))
        store.dependencies.scheduleStore.saveRoutine = { _ in throw SaveFailed() }
        store.dependencies.scheduleStore.saveKid = { kid in kids.withValue { $0.append(kid) } }
        await store.send(.task)
        await store.receive(\.loaded)
        await store.receive(\.reload)
        await store.receive(\.loaded)
        XCTAssertEqual(kids.value, [], "no record write after a failed template save")
        XCTAssertEqual(store.state.days.first?.slots.first { $0.kind == .school }?.end, 840,
                       "today still reads the waiting hours by date")
    }

    /// Board A1 on a live bus morning: "Leave in" counts to the chosen bus and the status shows.
    /// Made-up stop and bus numbers (privacy rule).
    func testLiveBusMorningShowsTheStatus() async {
        var snapshot = snapshot()
        snapshot.busPlans = [BusPlan(kid: SeedData.kidA.id, stop: "00000", services: ["1"])]
        let store = store(on: tuesday, minute: 412, snapshot: snapshot)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.receive(\.refresh)
        await store.receive(\.arrivalsLoaded)
        XCTAssertEqual(store.state.minutesToLeave, 18)
        XCTAssertEqual(store.state.status?.text, "On time")
    }

    func testLoadsTwoKidsLayout() async {
        let store = store(on: wednesday, minute: 945)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.days.count, 2)
        XCTAssertEqual(store.state.today, wednesday)
        XCTAssertEqual(store.state.minute, 945)
        XCTAssertTrue(store.state.days.first?.slots.contains { $0.title == "Swimming" } ?? false)
    }

    /// Views hold no values: Kid B's pictures, the leave countdown and the clock come from State.
    func testTheViewReadsKidBAndTheCountdownFromState() async {
        let store = store(on: tuesday, minute: 412)   // 6:52 am, Kid A leaves at 7:25
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.leaveTimeLeft, HomeModel.TimeLeft(label: "Leave in", minutes: 33))
        let kidB = store.state.kidB
        XCTAssertEqual(kidB?.kid, store.state.days[1].kid)
        // 6:52 am: Kid B has Breakfast until 7:30 am, then Play "in 38 min".
        XCTAssertEqual(kidB?.now, NowItem(picture: .actBreakfast, title: "Breakfast", line: "until 7:30 am", showsStar: false))
        XCTAssertEqual(kidB?.next?.title, "Play")
        XCTAssertEqual(kidB?.next?.line, "in 38 min")
        XCTAssertEqual(store.state.leavePicture, .busDouble)
        XCTAssertEqual(store.state.nowLabel, "Now")
        XCTAssertEqual(store.state.nextLabel, "Next")
        XCTAssertEqual(store.state.clockHand, 412)
        XCTAssertFalse(store.state.clockSectors.isEmpty)

        let empty = HomeFeature.State()
        XCTAssertNil(empty.kidB)
        XCTAssertNil(empty.leaveTimeLeft)
        XCTAssertNil(empty.clockHand)
        XCTAssertNil(empty.leavePicture)
    }

    /// Spec "States" (v70): Kid B with an empty day reads "Nothing planned" with the play picture and
    /// no time line, and the Next row is left out even with tomorrow planned.
    func testKidBWithAnEmptyDaySaysNothingPlanned() {
        var state = HomeFeature.State()
        state.minute = 600
        let kid = SeedData.kidB
        let tomorrow = [Slot(title: "Sleep", iconName: "actSleep", kind: .sleep, start: 0, end: 420, source: .routine, showsStar: false),
                        Slot(title: "Breakfast", iconName: "actBreakfast", kind: .morning, start: 420, end: 450, source: .routine, showsStar: false)]
        state.days = [HomeFeature.KidDay(kid: SeedData.kidA, dayType: .weekday, slots: []),
                      HomeFeature.KidDay(kid: kid, dayType: .weekday, slots: [], tomorrowSlots: tomorrow)]
        XCTAssertEqual(state.kidB?.kid, kid)
        XCTAssertEqual(state.kidB?.now, NowItem(picture: .actPlay, title: "Nothing planned", line: nil, showsStar: false))
        XCTAssertNil(state.kidB?.next)
    }

    /// Spec "Now and next on home" (layout v68): every kid shows now once and next once. Kid A's block
    /// is one Next row ("in 38 min"), never a time left block over a second row for the same item;
    /// Kid B's Next row never repeats what is on now.
    func testEachItemShowsOncePerKid() async {
        let store = store(on: tuesday, minute: 862)   // 2:22 pm: Kid A at school, Kid B napping
        await store.send(.task)
        await store.receive(\.loaded)
        guard case let .next(item) = store.state.kidABlock else { return XCTFail("\(store.state.kidABlock)") }
        XCTAssertEqual(item.title, "Snack")
        XCTAssertEqual(item.line, "in 38 min")
        XCTAssertEqual(store.state.kidAEnd, .nextRow)
        XCTAssertNil(store.state.leaveNext)
        let kidB = store.state.kidB
        XCTAssertEqual(kidB?.now.title, "Nap")
        XCTAssertEqual(kidB?.now.line, "until 3:00 pm")
        XCTAssertEqual(kidB?.next?.title, "Snack")
        XCTAssertEqual(kidB?.next?.line, "in 38 min")
        // Every minute of the day: Kid B's Next row is a later thing than its Now row.
        var state = store.state
        for minute in stride(from: 0, to: 1440, by: 5) {
            state.minute = minute
            guard let rows = state.kidB, let next = rows.next else { continue }
            let now = DayPlanner.now(at: minute, in: state.days[1].slots).current
            XCTAssertNotEqual(now.map { $0.start }, next.start, "\(minute)")
            XCTAssertGreaterThanOrEqual(next.start + (next.start <= minute ? 1440 : 0), now?.end ?? minute, "\(minute)")
        }
    }

    /// Board A1n at 7:40 pm: Kid B asleep "until 6:30 am", Next is tomorrow's Breakfast.
    func testKidBAtNightShowsSleepThenTomorrowsBreakfast() async {
        let store = store(on: tuesday, minute: 1180)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.kidB?.now, NowItem(picture: .actSleep, title: "Sleep", line: "until 6:30 am",
                                                      showsStar: false))
        XCTAssertEqual(store.state.kidB?.next?.title, "Breakfast")
        XCTAssertEqual(store.state.kidB?.next?.line, "at 6:30 am")
    }

    /// The copy comes from the injected localizer: a test can check the keys.
    func testCopyComesFromTheInjectedLocalizer() {
        let state = withDependencies { $0.localizer = .keys } operation: { HomeFeature.State() }
        XCTAssertEqual(state.nextLabel, "home.next")
        XCTAssertEqual(state.nowLabel, "home.now")
        XCTAssertEqual(state.missionsTitle, "home.missions")
    }

    /// The day name follows the app's calendar: just after midnight in Singapore it is already Saturday,
    /// whatever the device's own time zone says.
    func testDayNameFollowsTheAppCalendar() async {
        let store = store(on: saturday, minute: 30)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.dayName, "Saturday")
    }

    /// Board A1n: night from the evening routine (7:15 pm) until wake-up (6:30 am).
    func testLookTurnsNightAtTheEveningRoutine() async {
        for (minute, look) in [(1154, KidLook.day), (1155, .night), (389, .night), (390, .day)] {
            let store = store(on: wednesday, minute: minute)
            await store.send(.task)
            await store.receive(\.loaded)
            XCTAssertEqual(store.state.look, look, "minute \(minute)")
        }
    }

    /// Board 0g: a tap swaps the look until the next planned change; taps while it animates are ignored.
    func testSkySwitchLastsUntilTheNextPlannedChange() async {
        let clock = TestClock()
        let store = store(on: wednesday, minute: 900)
        store.dependencies.continuousClock = clock
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.look, .day)

        await store.send(.skySwitchTapped)
        XCTAssertEqual(store.state.look, .night)
        await store.send(.skySwitchTapped)   // still animating: ignored
        XCTAssertEqual(store.state.look, .night)
        await clock.advance(by: .milliseconds(1200))
        await store.receive(\.skyAnimationEnded)

        // 7:14 pm: still the switch's night; 7:15 pm the plan turns night and the choice is gone.
        await store.send(.tick(wednesday.date(minute: 1154, calendar: calendar)))
        XCTAssertEqual(store.state.skyOverride, .night)
        await store.send(.tick(wednesday.date(minute: 1155, calendar: calendar)))
        XCTAssertNil(store.state.skyOverride)
        XCTAssertEqual(store.state.look, .night)
    }

    func testSkySwitchBackToThePlanClearsTheChoice() async {
        let clock = TestClock()
        let store = store(on: wednesday, minute: 900)
        store.dependencies.continuousClock = clock
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.skySwitchTapped)
        await clock.advance(by: .milliseconds(1200))
        await store.receive(\.skyAnimationEnded)
        await store.send(.skySwitchTapped)
        XCTAssertNil(store.state.skyOverride)
        XCTAssertEqual(store.state.look, .day)
        await clock.advance(by: .milliseconds(1200))
        await store.receive(\.skyAnimationEnded)
    }

    /// Board 0g2: after 20 s without a touch the clock winks; a touch restarts the count.
    func testIdleWinkEveryTwentySecondsWithoutATouch() async {
        let store = store(on: wednesday, minute: 600)
        await store.send(.task)
        await store.receive(\.loaded)
        let now = wednesday.date(minute: 600, calendar: calendar)
        for _ in 0..<19 { await store.send(.tick(now)) }
        XCTAssertEqual(store.state.winks, 0)
        await store.send(.touched)
        for _ in 0..<19 { await store.send(.tick(now)) }
        XCTAssertEqual(store.state.winks, 0)
        await store.send(.tick(now))
        XCTAssertEqual(store.state.winks, 1)
    }

    /// Board 0g2: the new-slot hop and the hour pulse follow State.
    func testCurrentSlotAndHourFollowTheMinute() async {
        let store = store(on: wednesday, minute: 445)   // 7:25 am, breakfast
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.currentSlotStart, 390)
        XCTAssertEqual(store.state.hour, 7)
        await store.send(.tick(wednesday.date(minute: 450, calendar: calendar)))   // 7:30 am, school
        XCTAssertEqual(store.state.currentSlotStart, 450)
    }

    /// Spec "Hub text" (layout v71, board E3h): on a public holiday the full weekday is red with the
    /// holiday's name under it. Dates and names from the bundled lists: Monday 9 Nov 2026 is
    /// Deepavali (observed).
    func testAPublicHolidayTurnsTheWeekdayRedWithItsName() async {
        let monday = Day(year: 2026, month: 11, day: 9)
        let store = store(on: monday, minute: 600, holidays: [Holiday(day: monday, name: "Deepavali (observed)")])
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.dayHeading, "Monday", "the full weekday, no \"· Holiday\"")
        XCTAssertTrue(store.state.isPublicHoliday)
        XCTAssertEqual(store.state.dayNote, "Deepavali (observed)")
        XCTAssertTrue(store.state.hasDayNote)
        XCTAssertEqual(store.state.days.map(\.dayType), [.sunday, .sunday], "everyone is off")
    }

    /// Spec "Hub text": on a school break that is no public holiday the weekday stays ink and the
    /// break's name sits under it (Wednesday 10 Jun 2026 in the MOE June holidays).
    func testASchoolBreakKeepsTheWeekdayInkWithTheBreaksName() async {
        let june10 = Day(year: 2026, month: 6, day: 10)
        let store = store(on: june10, minute: 600, breaks: [june10: "June holidays"])
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.dayHeading, "Wednesday")
        XCTAssertFalse(store.state.isPublicHoliday)
        XCTAssertEqual(store.state.dayNote, "June holidays")
        XCTAssertEqual(store.state.days.map(\.dayType), [.sunday, .weekday], "Kid B (no school) keeps the weekday")
    }

    /// A public holiday inside a break: red, with the holiday's name (Monday 1 Jun 2026, Vesak Day
    /// (observed), in the June holidays).
    func testAPublicHolidayInsideABreakNamesTheHoliday() async {
        let june1 = Day(year: 2026, month: 6, day: 1)
        let store = store(on: june1, minute: 600, holidays: [Holiday(day: june1, name: "Vesak Day (observed)")],
                          breaks: [june1: "June holidays"])
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertTrue(store.state.isPublicHoliday)
        XCTAssertEqual(store.state.dayNote, "Vesak Day (observed)")
    }

    /// A school day, and a weekend inside a break: the weekday alone, in ink. A public holiday on a
    /// Sunday is red all the same (Sunday 31 May 2026, Vesak Day).
    func testNoLineOnASchoolDayOrABreaksWeekend() async {
        let school = store(on: tuesday, minute: 600)
        await school.send(.task)
        await school.receive(\.loaded)
        XCTAssertEqual(school.state.dayHeading, "Tuesday")
        XCTAssertFalse(school.state.isPublicHoliday)
        XCTAssertNil(school.state.dayNote)
        XCTAssertFalse(school.state.hasDayNote)
        let june13 = Day(year: 2026, month: 6, day: 13)
        let weekend = store(on: june13, minute: 600, breaks: [june13: "June holidays"])
        await weekend.send(.task)
        await weekend.receive(\.loaded)
        XCTAssertEqual(weekend.state.dayHeading, "Saturday")
        XCTAssertNil(weekend.state.dayNote, "a break's name only on a weekday (spec E3)")
        let may31 = Day(year: 2026, month: 5, day: 31)
        let sunday = store(on: may31, minute: 600, holidays: [Holiday(day: may31, name: "Vesak Day")],
                           breaks: [may31: "June holidays"])
        await sunday.send(.task)
        await sunday.receive(\.loaded)
        XCTAssertTrue(sunday.state.isPublicHoliday)
        XCTAssertEqual(sunday.state.dayNote, "Vesak Day")
    }

    /// A school-closed weekday with no name (no break, no public holiday) shows the weekday alone.
    func testAClosedDayWithoutANameShowsTheWeekdayAlone() async {
        let store = store(on: wednesday, minute: 600, schoolClosed: [wednesday])
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.dayHeading, "Wednesday")
        XCTAssertNil(store.state.dayNote)
        XCTAssertEqual(store.state.days.map(\.dayType), [.sunday, .weekday])
    }

    /// Board A1z (layout v74): after Kid A's bedtime (Sleep has started) the block shows one row for
    /// the next day's first thing, its opening Sleep skipped. Before midnight: "Tomorrow", the title
    /// and "at {h:mm}" (Breakfast is no outing). Tuesday 10 Nov 2026, 9:15 pm; Sleep from 8:00 pm.
    func testAfterBedtimeKidAShowsTomorrowsFirstThing() async {
        let store = store(on: tuesday, minute: 1275)
        await store.send(.task)
        await store.receive(\.loaded)
        guard case let .tomorrow(row) = store.state.kidABlock else {
            return XCTFail("expected the Tomorrow row, got \(store.state.kidABlock)")
        }
        // Spec v74 (board A1z): the next day's first outing, School by bus (7:30, leave 5 min before).
        XCTAssertEqual(row.item.title, "School")
        XCTAssertEqual(row.item.line, "leave 7:25 am")
        XCTAssertEqual(row.inDays, 1)
        XCTAssertEqual(store.state.aheadCaption(row), "Tomorrow")
        XCTAssertEqual(store.state.kidAEnd, .nextRow, "Kid B hangs below it as on E3 (A1z: 452)")
        XCTAssertEqual(store.state.look, .night)
        // Just before Sleep the Bed row still shows (board A1n).
        let evening = self.store(on: tuesday, minute: 1185)
        await evening.send(.task)
        await evening.receive(\.loaded)
        guard case .bedTime = evening.state.kidABlock else { return XCTFail("expected the Bed row before 8:00 pm") }
    }

    /// Board A1z: when the next day starts with an outing, its line is "leave {h:mm}" (School by bus,
    /// leave 5 min before 7:00 am).
    func testTomorrowsOutingSaysWhenToLeave() async {
        var snapshot = snapshot()
        let blocks = [
            RoutineBlock(title: "Sleep", iconName: "actSleep", kind: .sleep, start: 0, end: 420, isLocked: false, trip: nil),
            RoutineBlock(title: "School", iconName: "wolfie", kind: .school, start: 420, end: 900, isLocked: true,
                         trip: Trip(way: .bus, leaveBefore: 5)),
            RoutineBlock(title: "Play", iconName: "blocks", kind: .play, start: 900, end: 1200, isLocked: false, trip: nil),
            RoutineBlock(title: "Sleep", iconName: "actSleep", kind: .sleep, start: 1200, end: 1440, isLocked: false, trip: nil),
        ]
        snapshot.routines.removeAll { $0.kid == SeedData.kidA.id && $0.dayType == .weekday }
        snapshot.routines.append(Routine(kid: SeedData.kidA.id, dayType: .weekday, from: SeedData.templatesFrom, blocks: blocks))
        let store = store(on: tuesday, minute: 1275, snapshot: snapshot)
        await store.send(.task)
        await store.receive(\.loaded)
        guard case let .tomorrow(row) = store.state.kidABlock else {
            return XCTFail("expected the Tomorrow row, got \(store.state.kidABlock)")
        }
        XCTAssertEqual(row.item.title, "School")
        XCTAssertEqual(row.item.line, "leave 6:55 am")
    }

    /// Spec v74: with no outing on the next day the row names its first thing after the opening
    /// Sleep (Saturday 14 Nov, 9:30 pm, to Sunday: Breakfast at 7:30 am, no outing).
    func testTomorrowWithoutAnOutingNamesItsFirstThing() async {
        let store = store(on: saturday, minute: 1290)
        await store.send(.task)
        await store.receive(\.loaded)
        guard case let .tomorrow(row) = store.state.kidABlock else {
            return XCTFail("expected the Tomorrow row, got \(store.state.kidABlock)")
        }
        XCTAssertEqual(row.item.title, "Breakfast")
        XCTAssertEqual(row.item.line, "at 7:30 am")
    }

    /// Spec v74: whenever today has nothing left (a day that does not end in Sleep, an empty day) Kid A
    /// shows the Tomorrow row too; with nothing at all in the next 14 days, the name only (A1z
    /// without the row).
    func testNothingLeftTodayShowsTheNextDayWithAPlan() async {
        // Tuesday 9:15 pm on a template that ends in Play (no Sleep): tomorrow's School.
        var playLate = snapshot()
        let blocks = [
            RoutineBlock(title: "Sleep", iconName: "actSleep", kind: .sleep, start: 0, end: 420, isLocked: false, trip: nil),
            RoutineBlock(title: "School", iconName: "wolfie", kind: .school, start: 420, end: 900, isLocked: true,
                         trip: Trip(way: .bus, leaveBefore: 5)),
            RoutineBlock(title: "Play", iconName: "blocks", kind: .play, start: 900, end: 1440, isLocked: false, trip: nil),
        ]
        playLate.routines.removeAll { $0.kid == SeedData.kidA.id && $0.dayType == .weekday }
        playLate.routines.append(Routine(kid: SeedData.kidA.id, dayType: .weekday, from: SeedData.templatesFrom, blocks: blocks))
        let late = store(on: tuesday, minute: 1275, snapshot: playLate)
        await late.send(.task)
        await late.receive(\.loaded)
        guard case let .tomorrow(row) = late.state.kidABlock else { return XCTFail("\(late.state.kidABlock)") }
        XCTAssertEqual(row.item.title, "School")
        XCTAssertEqual(row.inDays, 1)

        // Only a Saturday template and no items: on Tuesday the next plan is Saturday, 4 days on.
        var weekendOnly = snapshot()
        weekendOnly.items = []
        weekendOnly.routines.removeAll { $0.kid == SeedData.kidA.id && $0.dayType != .saturday }
        let empty = store(on: tuesday, minute: 600, snapshot: weekendOnly)
        await empty.send(.task)
        await empty.receive(\.loaded)
        guard case let .tomorrow(saturdayRow) = empty.state.kidABlock else { return XCTFail("\(empty.state.kidABlock)") }
        XCTAssertEqual(saturdayRow.inDays, 4)
        XCTAssertEqual(saturdayRow.item.title, "Breakfast")
        XCTAssertEqual(empty.state.aheadCaption(saturdayRow), "Saturday")
        XCTAssertEqual(empty.state.kidAEnd, .nextRow)

        // Spec #261: 7 or more days away the caption is the short date (a once item on Tue 17 Nov).
        var nextWeek = snapshot()
        nextWeek.routines.removeAll { $0.kid == SeedData.kidA.id }
        nextWeek.items = [ScheduleItem(id: UUID(), title: "Doctor", iconName: "doctor", audience: .kid(SeedData.kidA.id),
                                       start: 600, end: 660, recurrence: .once(Day(year: 2026, month: 11, day: 17)),
                                       skippedDays: [], skipsHolidays: false, showsStar: false)]
        let later = store(on: tuesday, minute: 600, snapshot: nextWeek)
        await later.send(.task)
        await later.receive(\.loaded)
        guard case let .tomorrow(weekRow) = later.state.kidABlock else { return XCTFail("\(later.state.kidABlock)") }
        XCTAssertEqual(weekRow.inDays, 7)
        XCTAssertEqual(later.state.aheadCaption(weekRow), "Tue 17 Nov")

        // Nothing in the next 14 days: the name only.
        var nothing = snapshot()
        nothing.items = []
        nothing.routines.removeAll { $0.kid == SeedData.kidA.id }
        let bare = store(on: tuesday, minute: 600, snapshot: nothing)
        await bare.send(.task)
        await bare.receive(\.loaded)
        XCTAssertEqual(bare.state.kidABlock, .nothing)
        XCTAssertEqual(bare.state.kidAEnd, .name)
    }

    /// Board A1z: after midnight the day is the new one, so the row is the ordinary Next row ("Next",
    /// "at 6:30 am" more than an hour ahead, "in {n} min" within the hour). Wednesday 11 Nov, 0:30 am.
    func testAfterMidnightTheRowIsTheOrdinaryNextRow() async {
        let store = store(on: wednesday, minute: 30)
        await store.send(.task)
        await store.receive(\.loaded)
        guard case let .next(next) = store.state.kidABlock else { return XCTFail("expected the Next row") }
        XCTAssertEqual(next.title, "Breakfast")
        XCTAssertEqual(next.line, "at 6:30 am")
        XCTAssertEqual(store.state.nextLabel, "Next")
        let soon = self.store(on: wednesday, minute: 345)
        await soon.send(.task)
        await soon.receive(\.loaded)
        guard case let .next(row) = soon.state.kidABlock else { return XCTFail("expected the Next row") }
        XCTAssertEqual(row.line, "in 45 min")
    }

    /// Spec "Picture rigs": a tap plays the slot once; taps during the 1.2 s play are ignored.
    /// Every tapped picture plays at once; a picture still playing does not restart.
    func testEveryTappedPicturePlays() async {
        let clock = TestClock()
        let store = store(on: wednesday, minute: 600)
        store.dependencies.continuousClock = clock
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.slotTapped(450))
        await store.send(.slotTapped(900))
        XCTAssertEqual(store.state.plays, [450: 1, 900: 1], "two pictures play together")
        await store.send(.slotTapped(450))
        XCTAssertEqual(store.state.plays[450], 1, "a playing picture does not restart")
        await clock.advance(by: .milliseconds(1200))
        await store.receive(\.playEnded)
        await store.receive(\.playEnded)
        await store.send(.slotTapped(450))
        XCTAssertEqual(store.state.plays[450], 2)
        await clock.advance(by: .milliseconds(1200))
        await store.receive(\.playEnded)
    }

    /// Spec "Mission windows": the morning runs from wake-up to the leave, with Kid A's outing.
    func testMissionMorningShowsTheOutingAndTheButton() async {
        let early = store(on: tuesday, minute: 412)   // 6:52 am
        await early.send(.task)
        await early.receive(\.loaded)
        XCTAssertTrue(early.state.showsMissions)
        XCTAssertEqual(early.state.morningOuting?.slot.title, "School")
        XCTAssertEqual(early.state.outingHeading, "Leave in")
        XCTAssertEqual(early.state.minutesToLeave, 33)
        XCTAssertEqual(early.state.morningOuting?.trip.way, .bus)

        let beforeWake = store(on: tuesday, minute: 380)
        await beforeWake.send(.task)
        await beforeWake.receive(\.loaded)
        XCTAssertFalse(beforeWake.state.showsMissions)

        let noon = store(on: tuesday, minute: 720)
        await noon.send(.task)
        await noon.receive(\.loaded)
        XCTAssertFalse(noon.state.showsMissions)
        XCTAssertNil(noon.state.morningOuting)
    }

    /// Spec "Mission windows": the button needs missions in the open window, and the morning ends
    /// when Kid A leaves (Kid B, at home, keeps hers until noon).
    func testTheButtonFollowsTheWindowsWithMissions() async {
        let none = store(on: tuesday, minute: 412,
                         snapshot: ScheduleSnapshot(kids: SeedData.kids, routines: SeedData.routines, items: []))
        await none.send(.task)
        await none.receive(\.loaded)
        XCTAssertFalse(none.state.showsMissions, "no missions, no button")
        XCTAssertEqual(none.state.morningOuting?.slot.title, "School", "the countdown does not need missions")

        let kidAOnly = store(on: tuesday, minute: 450, snapshot: snapshot(kids: [SeedData.kidA]))
        await kidAOnly.send(.task)
        await kidAOnly.receive(\.loaded)
        XCTAssertFalse(kidAOnly.state.showsMissions, "Kid A has left for school")

        let both = store(on: tuesday, minute: 450)
        await both.send(.task)
        await both.receive(\.loaded)
        XCTAssertTrue(both.state.showsMissions, "Kid B's morning runs to noon")
    }

    /// Spec "Home button label per window": "Before {item}" names the outing the missions lead to;
    /// a name too long for one line falls back to "Missions".
    func testTheButtonNamesTheWindow() async {
        func swimming(named name: String) -> ScheduleSnapshot {
            let items = SeedData.items(today: tuesday, calendar: calendar).map { item -> ScheduleItem in
                guard item.title == "Swimming" else { return item }
                var swimming = item
                swimming.title = name
                swimming.bring = [ItemMission(id: UUID(), name: "Towel", picture: "towel")]
                return swimming
            }
            return ScheduleSnapshot(kids: [SeedData.kidA], routines: SeedData.routines, items: items,
                                    missions: SeedData.missions)
        }
        let monday = Day(year: 2026, month: 11, day: 16)
        let morning = store(on: monday, minute: 400, snapshot: swimming(named: "Swimming"))
        await morning.send(.task)
        await morning.receive(\.loaded)
        XCTAssertEqual(morning.state.missionsTitle, "Missions")

        let afterSchool = store(on: monday, minute: 905, snapshot: swimming(named: "Swimming"))
        await afterSchool.send(.task)
        await afterSchool.receive(\.loaded)
        XCTAssertTrue(afterSchool.state.showsMissions)
        XCTAssertEqual(afterSchool.state.missionsTitle, "Before Swimming")

        let long = store(on: monday, minute: 905, snapshot: swimming(named: "Swimming lessons"))
        await long.send(.task)
        await long.receive(\.loaded)
        XCTAssertEqual(long.state.missionsTitle, "Missions")
    }

    func testAnOutingMoreThanThreeHoursAwayShowsTheNextRowInstead() async {
        // Monday 10:00 am: school has started; swimming at 3:30 pm is more than 3 hours away.
        let store = store(on: Day(year: 2026, month: 11, day: 16), minute: 600)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertTrue(store.state.showsMissions)
        XCTAssertNil(store.state.morningOuting)
    }

    /// Spec "Now and next on home": Kid A's block per time of day (boards A1, A1n, E3).
    func testKidABlockFollowsTheTimeOfDay() async {
        let morning = store(on: tuesday, minute: 412)   // 6:52 am, leaving for school
        await morning.send(.task)
        await morning.receive(\.loaded)
        XCTAssertEqual(morning.state.kidABlock, .leave)

        let school = store(on: tuesday, minute: 630)    // 10:30 am, at school: the Next row only
        await school.send(.task)
        await school.receive(\.loaded)
        guard case let .next(row) = school.state.kidABlock else { return XCTFail("\(school.state.kidABlock)") }
        XCTAssertGreaterThan(row.start, 630)
        XCTAssertEqual(row.line, "at 3:00 pm")   // over an hour away: the time of day

        let evening = store(on: tuesday, minute: 1170)  // 7:30 pm: bed within 3 hours
        await evening.send(.task)
        await evening.receive(\.loaded)
        // A1n: bed time first, then tomorrow's outing (no Next row at night).
        guard case let .bedTime(left, tomorrow) = evening.state.kidABlock else {
            return XCTFail("\(evening.state.kidABlock)")
        }
        XCTAssertEqual(left.label, "Bed in")
        // Layout v73: "Tomorrow · School" over "leave 7:25 am" (School 7:30, 5 min by bus).
        XCTAssertEqual(evening.state.tomorrowLabel, "Tomorrow")
        XCTAssertEqual(tomorrow?.item.title, "School")
        XCTAssertEqual(tomorrow?.item.line, "leave 7:25 am")
    }

    /// E1: one kid keeps the Next row under "Leave in" on a leaving morning.
    func testOneKidKeepsTheNextRowWhenLeaving() async {
        let store = store(on: tuesday, minute: 412, snapshot: snapshot(kids: [SeedData.kidA]))
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.kidABlock, .leave)
        // v70: the Next row names the next thing other than the outing's item, never the item again.
        let outing = store.state.morningOuting?.slot
        XCTAssertNotNil(store.state.leaveNext)
        XCTAssertNotEqual(store.state.leaveNext?.start, outing?.start)
        XCTAssertGreaterThanOrEqual(store.state.leaveNext?.start ?? 0, outing?.end ?? .max)

        let two = self.store(on: tuesday, minute: 412)
        await two.send(.task)
        await two.receive(\.loaded)
        XCTAssertNil(two.state.leaveNext)
    }

    func testWeekendShowsTheNextRow() async {
        let store = store(on: saturday, minute: 600)
        await store.send(.task)
        await store.receive(\.loaded)
        guard case .next = store.state.kidABlock else { return XCTFail("\(store.state.kidABlock)") }
    }

    func testLoadFailureShowsAnEmptyDay() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: { [calendar, wednesday] in
            $0.calendar = calendar
            $0.date.now = wednesday.date(minute: 600, calendar: calendar)
            $0.scheduleStore.load = { throw CocoaError(.fileReadCorruptFile) }
            $0.holidays.holidays = { _ in [] }
            $0.schoolDirectory.calendar = { _, _ in .none }
        }
        store.exhaustivity = .off
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.days, [])
    }

    func testMidnightTickReloadsTheNewDay() async {
        let store = store(on: tuesday, minute: 1439)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertFalse(store.state.days.first?.slots.contains { $0.title == "Swimming" } ?? true)
        await store.send(.tick(wednesday.date(minute: 0, calendar: calendar)))
        XCTAssertEqual(store.state.today, wednesday)
        XCTAssertEqual(store.state.minute, 0)
        await store.receive(\.loaded)
        XCTAssertTrue(store.state.days.first?.slots.contains { $0.title == "Swimming" } ?? false)
    }

    func testTickBeforeTaskDoesNotLoad() async {
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: { [calendar] in
            $0.calendar = calendar
        }
        await store.send(.tick(wednesday.date(minute: 601, calendar: calendar))) {
            $0.minute = 601
            $0.idleSeconds = 1
            $0.now = self.wednesday.date(minute: 601, calendar: self.calendar)
            $0.secondsSinceRefresh = 1
        }
    }

    func testMinuteTickMovesNowWithoutReload() async {
        let store = store(on: wednesday, minute: 600)
        store.exhaustivity = .on
        await store.send(.task) {
            $0.today = self.wednesday
            $0.weekday = .wednesday
            $0.minute = 600
        }
        await store.skipReceivedActions()
        await store.send(.tick(wednesday.date(minute: 601, calendar: calendar))) {
            $0.minute = 601
            $0.idleSeconds = 1
            $0.now = self.wednesday.date(minute: 601, calendar: self.calendar)
            $0.secondsSinceRefresh = 1
        }
    }
}
