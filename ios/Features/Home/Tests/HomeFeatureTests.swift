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
                         items: SeedData.items(today: tuesday, calendar: calendar))
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
        }
        store.exhaustivity = .off
        return store
    }

    func testLoadsTwoKidsLayout() async {
        let store = store(on: wednesday, minute: 945)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.layout, .twoKids)
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
    func testSlotTapPlaysOnceAtATime() async {
        let clock = TestClock()
        let store = store(on: wednesday, minute: 600)
        store.dependencies.continuousClock = clock
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.slotTapped(450))
        XCTAssertEqual(store.state.plays[450], 1)
        await store.send(.slotTapped(450))
        await store.send(.slotTapped(900))
        XCTAssertEqual(store.state.plays, [450: 1], "ignored while playing")
        await clock.advance(by: .milliseconds(1200))
        await store.receive(\.playEnded)
        await store.send(.slotTapped(450))
        XCTAssertEqual(store.state.plays[450], 2)
        await clock.advance(by: .milliseconds(1200))
        await store.receive(\.playEnded)
    }

    func testOneKidLayout() async {
        let store = store(on: wednesday, minute: 600, snapshot: snapshot(kids: [SeedData.kidA]))
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.layout, .oneKid)
    }

    func testWeekendIsDayOffLayout() async {
        let store = store(on: saturday, minute: 600)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.layout, .dayOff)
    }

    func testHolidayIsDayOffLayout() async {
        let store = store(on: wednesday, minute: 600, holidays: [Holiday(day: wednesday, name: "Holiday")])
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.layout, .dayOff)
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
}
