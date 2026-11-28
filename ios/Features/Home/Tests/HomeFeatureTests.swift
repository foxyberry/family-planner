import AppSettings
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

    func testLoadsTwoKidsLayout() async {
        let store = store(on: wednesday, minute: 945)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.days.count, 2)
        XCTAssertEqual(store.state.today, wednesday)
        XCTAssertEqual(store.state.minute, 945)
        XCTAssertTrue(store.state.days.first?.slots.contains { $0.title == "Swimming" } ?? false)
    }

    /// The copy comes from the injected localizer: a test can check the keys.
    func testCopyComesFromTheInjectedLocalizer() {
        let state = withDependencies { $0.localizer = .keys } operation: { HomeFeature.State() }
        var thing = NextThing(id: "a", kids: [], title: "School", iconName: "actSchool", act: 450, inDays: 1,
                              day: Day(year: 2026, month: 11, day: 11), weekday: .wednesday)
        guard case let .day(label, _) = state.timeCell(thing) else { return XCTFail("a day label") }
        XCTAssertEqual(label, "home.tomorrow")
        thing.inDays = 0
        thing.act = 60
        XCTAssertEqual(state.timeCell(thing), .soon(number: "60", unit: "home.min", dots: 6))
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
        }
    }

    // MARK: Spec A1 (layout v78): the family's next things, the clock kid and the chips

    /// The list is the family's next things nearest first; the card is the first, the clock opens on
    /// its kid, and the chips show each kid with what they do now.
    func testTheCardIsTheNearestThingAndTheClockOpensOnItsKid() async {
        let store = store(on: wednesday, minute: 600)
        await store.send(.task)
        await store.receive(\.loaded)
        let things = store.state.things
        XCTAssertFalse(things.isEmpty)
        XCTAssertEqual(things, things.sorted { ($0.inDays, $0.act) < ($1.inDays, $1.act) })
        XCTAssertEqual(store.state.nextCard, things.first)
        XCTAssertEqual(store.state.clockKid, things.first?.kids.first)
        XCTAssertEqual(store.state.chips.map(\.id), SeedData.kids.map(\.id))
        XCTAssertEqual(store.state.chips.filter(\.isPicked).map(\.id), [store.state.clockKid].compactMap { $0 })
        XCTAssertTrue(store.state.chips.allSatisfy { $0.name == nil }, "two kids: no names on the chips")
        XCTAssertEqual(store.state.chipFit, .regular, "two kids: the full chips")
        let swimming = things.first { $0.title == "Swimming" }
        XCTAssertEqual(swimming?.kids, [SeedData.kidA.id])
        XCTAssertEqual(swimming.map { store.state.timeCell($0) }, .at(time: "3:20", period: "pm"), "leave 10 before 3:30")
    }

    /// Spec A1 "Kid chips": a tap turns the clock to that kid and fades the other kids' rows for 10 s
    /// after the last touch; a touch restarts the 10 s.
    func testAChipTapTurnsTheClockForTenSeconds() async {
        let clock = TestClock()
        let store = store(on: wednesday, minute: 600)
        store.dependencies.continuousClock = clock
        await store.send(.task)
        await store.receive(\.loaded)
        let other = SeedData.kids.map(\.id).first { $0 != store.state.clockKid }!
        await store.send(.kidChipTapped(other))
        XCTAssertEqual(store.state.clockKid, other)
        XCTAssertEqual(store.state.clockRim, SeedData.kids.first { $0.id == other }?.colorIndex)
        let theirs = store.state.things.filter { $0.kids.contains(other) }
        let others = store.state.things.filter { !$0.kids.contains(other) }
        XCTAssertTrue(theirs.allSatisfy { !store.state.isFaded($0) })
        XCTAssertTrue(others.allSatisfy { store.state.isFaded($0) })
        await clock.advance(by: .seconds(8))
        await store.send(.touched)
        await clock.advance(by: .seconds(8))
        XCTAssertEqual(store.state.clockKid, other, "the touch restarted the 10 s")
        await clock.advance(by: .seconds(2))
        await store.receive(\.chipTimeUp)
        XCTAssertNil(store.state.tappedKid)
        XCTAssertTrue(store.state.things.allSatisfy { !store.state.isFaded($0) })
    }

    /// Chip fit by the number of kids (design answer, 2026-11-23): three compact, four the face alone.
    func testChipsFitThreeAndFourKids() {
        let extra = (2...3).map { index in
            var kid = SeedData.kidB
            kid.id = UUID()
            kid.colorIndex = index
            return kid
        }
        var state = HomeFeature.State()
        state.days = ([SeedData.kidA, SeedData.kidB] + extra.prefix(1)).map { HomeFeature.KidDay(kid: $0, dayType: .weekday, slots: []) }
        XCTAssertEqual(state.chipFit, .compact)
        state.days = ([SeedData.kidA, SeedData.kidB] + extra).map { HomeFeature.KidDay(kid: $0, dayType: .weekday, slots: []) }
        XCTAssertEqual(state.chipFit, .faceOnly)
        XCTAssertEqual(state.chips.count, 4)
    }

    /// One kid (board E1): one chip with the name; a tap does nothing.
    func testOneKidHasOneNamedChip() async {
        let store = store(on: wednesday, minute: 600, snapshot: snapshot(kids: [SeedData.kidA]))
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.chips.map(\.name), [SeedData.kidA.name])
        await store.send(.kidChipTapped(SeedData.kidA.id))
        XCTAssertNil(store.state.tappedKid)
    }

    /// Spec A1 "Mission rows": on a mission morning Kid A's School is a mission row in Kid A's colour.
    func testAMissionMorningMakesTheOutingAMissionRow() async {
        let store = store(on: wednesday, minute: 400)
        await store.send(.task)
        await store.receive(\.loaded)
        let school = store.state.things.first { $0.title == "School" && $0.inDays == 0 }
        XCTAssertEqual(school?.missionKids, [SeedData.kidA.id])
        XCTAssertEqual(school.flatMap { store.state.hatch($0) }, .kid(SeedData.kidA.colorIndex))
        let later = store.state.things.first { !$0.isMission }
        XCTAssertNil(later.flatMap { store.state.hatch($0) })
    }

    /// Design 2026-11-23: an afternoon outing with a Bring list is a mission row too; one without stays plain.
    func testAnAfternoonOutingWithBringIsAMissionRow() async {
        var items = SeedData.items(today: tuesday, calendar: calendar)
        let index = items.firstIndex { $0.title == "Swimming" }!
        items[index].bring = [ItemMission(id: UUID(), name: "Goggles", picture: "actSwim")]
        let snapshot = ScheduleSnapshot(kids: SeedData.kids, routines: SeedData.routines, items: items,
                                        missions: SeedData.missions)
        let store = store(on: wednesday, minute: 840, snapshot: snapshot)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.things.first { $0.title == "Swimming" }?.missionKids, [SeedData.kidA.id])
        let plain = self.store(on: wednesday, minute: 840)
        await plain.send(.task)
        await plain.receive(\.loaded)
        XCTAssertEqual(plain.state.things.first { $0.title == "Swimming" }?.isMission, false)
    }

    /// Spec A1 "Hub": the clock kid's face, the weekday and the time; on a public holiday the weekday
    /// is red with its name under the time, and no face.
    func testTheHubNamesTheKidTheDayAndTheTime() async {
        let store = store(on: wednesday, minute: 412)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.clockHub.weekday, "Wednesday")
        XCTAssertEqual(store.state.clockHub.time, "6:52")
        XCTAssertNotNil(store.state.clockHub.face)
        XCTAssertNil(store.state.clockHub.holiday)
        let holiday = self.store(on: wednesday, minute: 412, holidays: [Holiday(day: wednesday, name: "Example Day")])
        await holiday.send(.task)
        await holiday.receive(\.loaded)
        XCTAssertEqual(holiday.state.clockHub.holiday, "Example Day")
        XCTAssertNil(holiday.state.clockHub.face)
    }
}
