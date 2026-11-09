import AppSettings
import BusClient
import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import HolidayProvider
import Home
import ScheduleStore
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
                       holidays: [Holiday] = []) -> TestStoreOf<HomeFeature> {
        let snapshot = snapshot ?? self.snapshot()
        let store = TestStore(initialState: HomeFeature.State()) {
            HomeFeature()
        } withDependencies: { [calendar] in
            $0.calendar = calendar
            $0.date.now = day.date(minute: minute, calendar: calendar)
            $0.scheduleStore.load = { snapshot }
            $0.holidays.holidays = { _ in holidays }
            $0.bus.arrivals = { _ in
                [BusArrival(service: "1", minutes: 4, type: .single), BusArrival(service: "1", minutes: 28, type: .double)]
            }
        }
        store.exhaustivity = .off
        return store
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

    /// S4 "Live bus times" off: home never calls LTA and shows no live status.
    func testLiveTimesOffNeverCallsLTA() async {
        var snapshot = snapshot()
        snapshot.busPlans = [BusPlan(kid: SeedData.kidA.id, stop: "00000", services: ["1"])]
        let called = LockIsolated(false)
        let store = store(on: tuesday, minute: 412, snapshot: snapshot)
        store.dependencies.appSettings.load = { AppSettings(liveBusTimes: false) }
        store.dependencies.bus.arrivals = { _ in called.setValue(true); return [] }
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertFalse(called.value)
        XCTAssertNil(store.state.status)
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
        XCTAssertEqual(store.state.skySwitchLabel, "Day. Tap for night.")

        await store.send(.skySwitchTapped)
        XCTAssertEqual(store.state.look, .night)
        XCTAssertEqual(store.state.skySwitchLabel, "Night. Tap for day.")
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

    /// Board E3: only a weekday school holiday says "Holiday · no school today".
    func testSchoolHolidayLineOnlyOnAWeekdayHoliday() async {
        let holiday = store(on: wednesday, minute: 600, holidays: [Holiday(day: wednesday, name: "Holiday")])
        await holiday.send(.task)
        await holiday.receive(\.loaded)
        XCTAssertTrue(holiday.state.isSchoolHoliday)
        XCTAssertEqual(holiday.state.dayHeading, "Wednesday · Holiday")
        let weekend = store(on: saturday, minute: 600)
        await weekend.send(.task)
        await weekend.receive(\.loaded)
        XCTAssertFalse(weekend.state.isSchoolHoliday)
        XCTAssertEqual(weekend.state.dayHeading, "Saturday")
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

        let evening = store(on: tuesday, minute: 1170)  // 7:30 pm: bed within 3 hours
        await evening.send(.task)
        await evening.receive(\.loaded)
        // A1n: bed time first, then tomorrow's outing (no Next row at night).
        guard case let .bedTime(left, tomorrow) = evening.state.kidABlock else {
            return XCTFail("\(evening.state.kidABlock)")
        }
        XCTAssertEqual(left.label, "Bed in")
        XCTAssertEqual(tomorrow?.title, "Tomorrow")
        XCTAssertEqual(tomorrow?.line.hasPrefix("School, leave "), true)
    }

    /// E1: one kid keeps the Next row under "Leave in" on a leaving morning.
    func testOneKidKeepsTheNextRowWhenLeaving() async {
        let store = store(on: tuesday, minute: 412, snapshot: snapshot(kids: [SeedData.kidA]))
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.kidABlock, .leave)
        XCTAssertNotNil(store.state.leaveNext)

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
