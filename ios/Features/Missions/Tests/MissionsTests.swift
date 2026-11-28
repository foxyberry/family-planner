import AppSettings
import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import HolidayProvider
import KitArt
import Localization
import Missions
import ScheduleStore
import SchoolDirectory
import XCTest

@MainActor
final class MissionsTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return calendar
    }()
    private let tuesday = Day(year: 2026, month: 11, day: 10)
    private let saturday = Day(year: 2026, month: 11, day: 14)
    private let kidA = SeedData.kidA.id
    private let kidB = SeedData.kidB.id

    private func store(on day: Day, minute: Int, missions: [Mission] = SeedData.missions, items: [ScheduleItem]? = nil,
                       saved: LockIsolated<[MissionDay]> = LockIsolated([]),
                       arrivals: [BusArrival]? = nil, services: [String] = ["1"], rides: [String: Int] = [:],
                       changes: [BusChange] = [], chosen: Kid.ID? = nil, opened: ListRef? = nil) -> TestStoreOf<MissionsFeature> {
        // Made-up stop and bus numbers (privacy rule).
        let plans = arrivals == nil ? [] : [BusPlan(kid: SeedData.kidA.id, stop: "00000", services: services,
                                                    rides: rides, changes: changes)]
        let snapshot = ScheduleSnapshot(kids: SeedData.kids, routines: SeedData.routines,
                                        items: items ?? SeedData.items(today: tuesday, calendar: calendar), missions: missions,
                                        busPlans: plans)
        var initial = MissionsFeature.State()
        initial.chosen = chosen
        initial.opened = opened
        let store = TestStore(initialState: initial) {
            MissionsFeature()
        } withDependencies: { [calendar] in
            $0.calendar = calendar
            $0.date.now = day.date(minute: minute, calendar: calendar)
            $0.continuousClock = TestClock()
            $0.scheduleStore.load = { snapshot }
            // The store keeps each list's marks and the outing's slide; `saved` holds the event list's
            // marks and the slide joined back into one day per kid, for the assertions.
            $0.scheduleStore.windowMissions = { kid, date, window in
                WindowMissions(kid: kid, date: date, window: window,
                               done: window == .morning ? [] : saved.value.first { $0.kid == kid && $0.date == date }?.done ?? [])
            }
            $0.scheduleStore.saveWindowMissions = { marks in
                guard marks.window != .morning else { return }
                saved.withValue { list in
                    var day = list.first { $0.kid == marks.kid && $0.date == marks.date }
                        ?? MissionDay(kid: marks.kid, date: marks.date)
                    day.done = marks.done
                    list.removeAll { $0.kid == marks.kid && $0.date == marks.date }
                    list.append(day)
                }
            }
            $0.scheduleStore.slides = { kid, date in [] }
            $0.scheduleStore.saveSlide = { slide in
                saved.withValue { list in
                    var day = list.first { $0.kid == slide.kid && $0.date == slide.date }
                        ?? MissionDay(kid: slide.kid, date: slide.date)
                    day.ready = slide.ready
                    day.readyAt = slide.readyAt
                    day.medal = slide.medal
                    list.removeAll { $0.kid == slide.kid && $0.date == slide.date }
                    list.append(day)
                }
            }
            $0.holidays.holidays = { _ in [] }
            $0.schoolDirectory.calendar = { _, _ in .none }
            // nil: no live times (no key built in), so the call fails and the timetable shows.
            $0.bus.arrivals = { _ in
                guard let arrivals else { throw URLError(.userAuthenticationRequired) }
                return arrivals
            }
        }
        store.exhaustivity = .off
        return store
    }

    private func id(_ suffix: String) -> Mission.ID { UUID(uuidString: "5EED0000-0000-4000-8000-000000000\(suffix)")! }

    /// Board A2-MVP, Tuesday 6:52 am: Kid A leaves first (bus at 7:25 am), the road goes to school.
    func testTuesdayMorningShowsTheWayToSchool() async {
        let store = store(on: tuesday, minute: 412)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.chosen, kidA)
        XCTAssertEqual(store.state.leaveAt, "leave at 7:25 am")
        let way = try? XCTUnwrap(store.state.way)
        XCTAssertEqual(way?.cardCaption, "by bus · no live times")
        XCTAssertEqual(way?.homeLabel, "Our stop")
        XCTAssertEqual(way?.place, "School")
        XCTAssertEqual(way?.showsStops, true)
        XCTAssertEqual(store.state.header?.minutes, "33 min")
        XCTAssertEqual(way?.moverX, 60) // 33 min to leave: 30 or more sits at x 60
        XCTAssertEqual(store.state.rows.map(\.total), [6, 0], "Kid B has no outing today, so no list (issue 024)")
        XCTAssertEqual(store.state.state(caption: 0), "0 of 6 done")
    }

    /// Spec A1 "Mission rows": opened from Kid B's row, A2 stays on Kid B after it loads.
    func testOpenedOnAKidStaysOnThatKid() async {
        let store = store(on: tuesday, minute: 412, chosen: SeedData.kidB.id)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.chosen, SeedData.kidB.id)
    }

    /// Board A2-MVP-w, Saturday 8:00 am: weekend school by car, "Home" on the stem, no stops.
    func testSaturdayGoesByCarFromHome() async {
        let store = store(on: saturday, minute: 480)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.chosen, kidA)
        XCTAssertEqual(store.state.way?.homeLabel, "Home")
        XCTAssertEqual(store.state.way?.showsStops, false)
        XCTAssertEqual(store.state.way?.cardCaption, "by car")
        XCTAssertEqual(store.state.leaveAt, "leave at 8:35 am")
    }

    func testTappingAMissionTicksAndUnticksItAndSaves() async {
        let saved = LockIsolated<[MissionDay]>([])
        let store = store(on: tuesday, minute: 412, saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)

        await store.send(.missionTapped(id("301")))
        XCTAssertEqual(store.state.rows.first?.done, 1)
        XCTAssertEqual(store.state.state(caption: 0), "1 of 6 done")
        // The first open mission is the bold one.
        XCTAssertEqual(store.state.circles.first { if case .mission(_, _, true) = $0 { true } else { false } }?.id,
                       id("302").uuidString)
        await store.finish(timeout: .seconds(1))
        XCTAssertEqual(saved.value.first?.done, [id("301")])

        await store.send(.missionTapped(id("301")))
        XCTAssertEqual(store.state.rows.first?.done, 0)
    }

    /// Every kid slides (user, 2026-11-09): Kid B has no outing, so "All done? Slide!" with the star,
    /// no medal, and the check with "Ready!" in the done view.
    func testAKidWithNoOutingSlidesWithTheStar() async {
        let store = store(on: tuesday, minute: 412)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.kidTapped(kidB))
        XCTAssertTrue(store.state.slides)
        XCTAssertEqual(store.state.slideTitle, "All done? Slide!")
        XCTAssertEqual(store.state.slideKnob, .star)
        await store.send(.slid)
        XCTAssertEqual(store.state.days[kidB]?.medal, MorningMedal.none)
        XCTAssertNil(store.state.done?.medal)
        XCTAssertEqual(store.state.done?.title, "Ready!")
        await store.send(.backTapped)
        await store.receive(\.delegate.finished)
    }

    func testTappingAMissionPlaysItsPicture() async {
        let store = store(on: tuesday, minute: 412)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.missionTapped(id("303")))
        XCTAssertEqual(store.state.plays[id("303")], 1)
        await store.send(.backTapped)
    }

    func testTappingAKidChoosesThem() async {
        let store = store(on: tuesday, minute: 412)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.kidTapped(kidB)) { $0.chosen = self.kidB }
        XCTAssertEqual(store.state.circles.count, 0, "Kid B has no outing today, so no list (issue 024)")
    }

    /// Spec "Whose outing": the strip shows the family's next outing whichever kid is chosen; Kid B
    /// has no trip of their own, so no "leave at".
    func testKidBKeepsTheFamilyWay() async {
        let store = store(on: tuesday, minute: 412)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.kidTapped(kidB))
        XCTAssertEqual(store.state.way?.owner.id, kidA)
        XCTAssertEqual(store.state.way?.cardCaption, "by bus · no live times")
        XCTAssertEqual(store.state.header?.minutes, "33 min")
        XCTAssertNil(store.state.leaveAt)
    }

    /// Review of #159: a route with no buses left (the last one removed) shows the timetable, not a
    /// live look with no bus to choose.
    func testAnEmptyRouteShowsTheTimetable() async {
        let store = store(on: tuesday, minute: 412, arrivals: [BusArrival(service: "1", minutes: 28, type: .double)],
                          services: [])
        await store.send(.task)
        await store.receive(\.loaded)
        await store.receive(\.refresh)
        // No LTA call for a route with no buses (review of #159): nothing loads.
        XCTAssertNil(store.state.live)
        XCTAssertNil(store.state.liveStrip)
        await store.send(.backTapped)
    }

    /// Spec "A2 live look": fresh live times give "Leave in" with "On time", and the chosen bus sets
    /// "leave at".
    func testLiveTimesShowLeaveInAndOnTime() async {
        let store = store(on: tuesday, minute: 412, arrivals: [BusArrival(service: "1", minutes: 4, type: .single),
                                                               BusArrival(service: "1", minutes: 28, type: .double)])
        await store.send(.task)
        await store.receive(\.loaded)
        await store.receive(\.refresh)
        await store.receive(\.arrivalsLoaded)
        XCTAssertEqual(store.state.live?.leaveIn, 18)
        XCTAssertEqual(store.state.header?.label, "Leave in")
        XCTAssertEqual(store.state.header?.minutes, "18 min")
        XCTAssertEqual(store.state.header?.status?.text, "On time")
        XCTAssertEqual(store.state.leaveAt, "leave at 7:10 am")
        // The strip: bus 1 in 4 min is too soon (faded, its tag shows its minutes), bus 1 in 28 min is the kid's.
        let buses = store.state.liveStrip?.buses ?? []
        XCTAssertEqual(buses.map(\.isMine), [false, true])
        XCTAssertEqual(buses.first?.tag, .bus(number: "1", then: nil, minutes: "4 min"))
        XCTAssertNil(buses.last?.tag)
        XCTAssertEqual(buses.last?.x, 860 - 28 * 800 / 30)
        await store.send(.backTapped)
    }

    /// Spec "Several buses": the bus that gets there first is my bus; every other arrival is faded
    /// with its tag, a bus that changes reads "3 → 4"; the legend lists the other buses.
    func testEveryBusIsShownAndTheFastestIsMine() async {
        let store = store(on: tuesday, minute: 412,
                          arrivals: [BusArrival(service: "1", minutes: 18, type: .double),
                                     BusArrival(service: "2", minutes: 12, type: .single),
                                     BusArrival(service: "3", minutes: 14, type: .single),
                                     BusArrival(service: "2", minutes: 40, type: .single)],
                          services: ["1", "2"], rides: ["2": 25],
                          changes: [BusChange(firstBus: "3", thenBus: "4", ride1: 8, change: 5, ride2: 6)])
        await store.send(.task)
        await store.receive(\.loaded)
        await store.receive(\.refresh)
        await store.receive(\.arrivalsLoaded)
        // Bus 1 reaches in 28, bus 2 in 37, bus 3 → 4 in 33: bus 1 is my bus though it comes last.
        XCTAssertEqual(store.state.live?.chosen?.route.service, "1")
        let strip = store.state.liveStrip
        XCTAssertEqual(strip?.buses.map(\.service), ["2", "3", "1"], "under 30 min, soonest first")
        XCTAssertEqual(strip?.buses.map(\.tag), [.bus(number: "2", then: nil, minutes: "12 min"),
                                                 .bus(number: "3", then: "4", minutes: "14 min"), nil])
        XCTAssertEqual(strip?.myService, "1")
        XCTAssertEqual(strip?.others, [WayStrip.Plate("2"), WayStrip.Plate("3", then: "4")])
        await store.send(.backTapped)
    }

    /// v61: an arrival of any first bus of a bus that changes counts, timed by its own Ride 1; its tag
    /// reads "{that bus} → {then}". The legend lists the other pills in pill order: the direct buses,
    /// then each bus that changes by its first buses ("2 · 3 → 8"), up to 3, then "+{n}".
    func testEveryFirstBusOfABusThatChangesCountsAndTheLegendNamesThePills() async {
        let store = store(on: tuesday, minute: 412,
                          arrivals: [BusArrival(service: "1", minutes: 18, type: .double),
                                     BusArrival(service: "2", minutes: 12, type: .single),
                                     BusArrival(service: "3", minutes: 14, type: .single)],
                          services: ["1"], rides: ["1": 30],
                          changes: [BusChange(firstBuses: ["2", "3"], thenBus: "8", rides1: ["2": 20, "3": 4],
                                              change: 5, ride2: 6),
                                    BusChange(firstBus: "5", thenBus: "6"),
                                    BusChange(firstBus: "7", thenBus: "9"),
                                    BusChange(firstBus: "1", thenBus: "4")])
        await store.send(.task)
        await store.receive(\.loaded)
        await store.receive(\.refresh)
        await store.receive(\.arrivalsLoaded)
        // Bus 3 → 8 reaches in 14 + 15 = 29, bus 2 → 8 in 12 + 31 = 43, bus 1 in 18 + 25 (via 4) = 43.
        XCTAssertEqual(store.state.live?.chosen?.route, BusRoute(service: "3", then: "8", trip: 15))
        let strip = store.state.liveStrip
        XCTAssertEqual(strip?.buses.map(\.tag), [.bus(number: "2", then: "8", minutes: "12 min"), nil,
                                                 .bus(number: "1", then: "4", minutes: "18 min")])
        XCTAssertEqual(strip?.myService, "3")
        // The chosen 3 leaves its pill "2 · 3 → 8" as "2 → 8".
        XCTAssertEqual(strip?.others, [WayStrip.Plate("1"), WayStrip.Plate("2", then: "8"), WayStrip.Plate("5", then: "6")])
        XCTAssertEqual(strip?.moreOthers, "+2")
        await store.send(.backTapped)
    }

    /// The legend names a bus that changes by all its first buses when another bus is mine.
    func testTheLegendJoinsTheFirstBuses() async {
        let store = store(on: tuesday, minute: 412,
                          arrivals: [BusArrival(service: "1", minutes: 12, type: .double)],
                          services: ["1"],
                          changes: [BusChange(firstBuses: ["2", "3"], thenBus: "8")])
        await store.send(.task)
        await store.receive(\.loaded)
        await store.receive(\.refresh)
        await store.receive(\.arrivalsLoaded)
        XCTAssertEqual(store.state.liveStrip?.myService, "1")
        XCTAssertEqual(store.state.liveStrip?.others, [WayStrip.Plate("2 · 3", then: "8")])
        await store.send(.backTapped)
    }

    /// Board A2t-w: on the weekend the greeting names the day.
    func testWeekendGreetingNamesTheDay() async {
        let saturday = Day(year: 2026, month: 11, day: 14)
        let store = store(on: saturday, minute: 480)
        await store.send(.task)
        XCTAssertEqual(store.state.title, "Good morning! Saturday")
        await store.send(.backTapped)
    }

    /// Board A2: a weekday greets without a day (the key once took the editor's "Missions · %@").
    func testWeekdayGreeting() async {
        let store = store(on: Day(year: 2026, month: 11, day: 10), minute: 480)
        await store.send(.task)
        XCTAssertEqual(store.state.title, "Good morning!")
        await store.send(.backTapped)
    }

    /// S4 "Medals" off: sliding at a gold time gives no medal.
    func testMedalsOffGiveNoMedal() async {
        let store = store(on: tuesday, minute: 440)
        store.dependencies.appSettings.load = { AppSettings(medals: false) }
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.slid)
        XCTAssertEqual(store.state.days[kidA]?.medal, MorningMedal.none)
        XCTAssertNil(store.state.rows[0].medal)
        XCTAssertNil(store.state.done?.medal)
        XCTAssertEqual(store.state.slideDoneKnob, .crown, "the crown in place of a medal")
        await store.send(.backTapped)
    }

    /// Live times with no bus to catch (only one arriving now): "Ask a grown-up", no leave time, and
    /// the legend still shows the kid's bus number.
    func testNoCatchableBusKeepsTheLegendAndDropsLeaveAt() async {
        let store = store(on: tuesday, minute: 412, arrivals: [BusArrival(service: "1", minutes: 0, type: .double)])
        await store.send(.task)
        await store.receive(\.loaded)
        await store.receive(\.refresh)
        await store.receive(\.arrivalsLoaded)
        XCTAssertNil(store.state.live?.leaveIn)
        XCTAssertNil(store.state.leaveAt)
        XCTAssertNil(store.state.header?.label, "no \"Leave in\" before \"Ask a grown-up\"")
        XCTAssertEqual(store.state.header?.status?.text, "Ask a grown-up")
        XCTAssertEqual(store.state.liveStrip?.myService, "1")
        await store.send(.backTapped)
    }

    /// No live times: the bus fallback counts to "leave" with no status.
    func testBusFallbackCountsToLeave() async {
        let store = store(on: tuesday, minute: 412)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertNil(store.state.live)
        XCTAssertEqual(store.state.header?.label, "Leave in")
        XCTAssertEqual(store.state.header?.minutes, "33 min")
        XCTAssertNil(store.state.header?.status)
        await store.send(.backTapped)
    }

    /// Spec "Medal from the time only" and board A3r: leave 7:25, so 7:20 is gold; the kid stays
    /// chosen with the done view however long the screen waits (board A3); a row tap picks the
    /// other kid; dragging back undoes.
    func testSlideShowsTheDoneViewUntilARowTapAndDragBackUndoes() async {
        let clock = TestClock()
        let store = store(on: tuesday, minute: 440)
        store.dependencies.continuousClock = clock
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertTrue(store.state.slides)
        XCTAssertEqual(store.state.slidePhase, .idle)
        await store.send(.slid)
        XCTAssertEqual(store.state.slidePhase, .done, "the slide rests done while the kid is ready")
        XCTAssertEqual(store.state.days[kidA]?.medal, .gold)
        XCTAssertEqual(store.state.days[kidA]?.readyAt, 440)
        XCTAssertEqual(store.state.caption(store.state.rows[0]), "Ready! Gold")
        XCTAssertEqual(store.state.rows[0].medal, .gold)
        XCTAssertEqual(store.state.chosen, kidA)
        XCTAssertEqual(store.state.done?.title, "Gold!")
        XCTAssertEqual(store.state.done?.subtitle, "Ready in good time!")
        await clock.advance(by: .seconds(10))
        XCTAssertEqual(store.state.chosen, kidA)
        XCTAssertEqual(store.state.done?.title, "Gold!")
        await store.send(.kidTapped(kidB))
        XCTAssertEqual(store.state.chosen, kidB)
        // Back to Kid A: the done view again; dragging the slide back undoes it.
        await store.send(.kidTapped(kidA))
        XCTAssertEqual(store.state.done?.medal, .gold)
        await store.send(.slideUndone)
        XCTAssertNil(store.state.days[kidA]?.medal)
        XCTAssertEqual(store.state.days[kidA]?.ready, false)
        XCTAssertEqual(store.state.slidePhase, .idle)
        XCTAssertNil(store.state.done)
        await store.send(.backTapped)
    }

    /// After the last outing has started the strip keeps its road with the mover arrived
    /// (user, 2026-11-09), for every kid; nothing counts down and no kid has a leave time.
    func testAStartedOutingKeepsItsRoad() async {
        let store = store(on: tuesday, minute: 11 * 60)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.way?.place, "School")
        XCTAssertEqual(store.state.way?.moverX, WayStrip.arrivedX)
        XCTAssertEqual(store.state.way?.cardCaption, "At School now")
        XCTAssertNil(store.state.leaveAt)
    }

    /// Eight missions with two kids: six places. Done ones fold into one tick; the last place
    /// is "+n" and turns the page.
    func testEightMissionsFoldAndPage() async {
        let extra = [Mission(id: id("307"), kid: kidA, name: "Water bottle", picture: "actPlay", order: 6),
                     Mission(id: id("308"), kid: kidA, name: "Hat", picture: "actPlay", order: 7)]
        let store = store(on: tuesday, minute: 412, missions: SeedData.missions + extra)
        await store.send(.task)
        await store.receive(\.loaded)

        // None done: five missions, then "+3".
        XCTAssertEqual(store.state.circles.count, 6)
        XCTAssertEqual(store.state.circles.last, .more(count: 3))
        await store.send(.moreTapped)
        XCTAssertEqual(store.state.circles.first?.id, id("306").uuidString)
        XCTAssertEqual(store.state.circles.last, .back)
        await store.send(.backPageTapped)
        XCTAssertEqual(store.state.circles.first?.id, id("301").uuidString)

        // Three done: one folded tick and the five open ones.
        for suffix in ["301", "302", "303"] { await store.send(.missionTapped(id(suffix))) }
        XCTAssertEqual(store.state.circles.first, .folded(count: 3))
        XCTAssertEqual(store.state.circles.count, 6)
        XCTAssertFalse(store.state.circles.contains { if case .more = $0 { true } else { false } })
    }

    /// Views hold no values: the circles' words and play ids come from State.
    func testCircleWordsAndPlayIDsComeFromState() {
        let state = MissionsFeature.State()
        XCTAssertEqual(state.name(of: .folded(count: 3)), "3 done")
        XCTAssertEqual(state.name(of: .more(count: 2)), "2 more")
        XCTAssertEqual(state.moreText(count: 2), "+2")
        XCTAssertEqual(state.name(of: .back), "Back")
        XCTAssertEqual(state.playID(of: id("301")), 0)
        XCTAssertEqual(state.picture(of: WindowMission(window: .morning, id: id("301"), name: "Teeth", picture: "toothbrush")),
                       .toothbrush)
        XCTAssertEqual(state.picture(of: WindowMission(window: .morning, id: id("302"), name: "Odd", picture: "noSuchPicture")),
                       .actPlay)

        let keys = withDependencies { $0.localizer = .keys } operation: { MissionsFeature.State() }
        XCTAssertEqual(keys.name(of: .folded(count: 3)), "missions.folded|3")
        XCTAssertEqual(keys.slideDoneTitle, "missions.ready")
    }

    /// Spec "Event lists", A2 "Opened from a row": A2 opens on that event's list, and the kid column
    /// holds only that event's kids.
    func testOpenedFromARowShowsThatEventsKids() async {
        let store = store(on: tuesday, minute: 412, opened: .event(.school))
        store.exhaustivity = .off
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.listSlots[kidA]?.kind, .school)
        XCTAssertEqual(store.state.kids.map(\.id), [kidA], "Kid B has no School today")
        XCTAssertEqual(store.state.rows.map(\.total), [6])
        await store.send(.backTapped)
    }

    /// Issue 024: today's marks from the old morning window move once to the kid's first list (School),
    /// and the morning record is emptied, so an untick sticks.
    func testMorningMarksMoveOnceToTheFirstList() async {
        let saves = LockIsolated<[WindowMissions]>([])
        let store = store(on: tuesday, minute: 412)
        store.exhaustivity = .off
        let packed = id("301")
        store.dependencies.scheduleStore.windowMissions = { [kidA] kid, date, window in
            WindowMissions(kid: kid, date: date, window: window, done: window == .morning && kid == kidA ? [packed] : [])
        }
        store.dependencies.scheduleStore.saveWindowMissions = { marks in saves.withValue { $0.append(marks) } }
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.rows.first?.done, 1)
        await store.finish(timeout: .seconds(1))
        XCTAssertTrue(saves.value.contains { $0.window == .before(.school) && $0.done == [packed] })
        XCTAssertTrue(saves.value.contains { $0.window == .morning && $0.done.isEmpty })
    }

    /// Spec "Mission windows": after school, Kid A's list is swimming's Bring checks; the slide
    /// belongs to swimming.
    func testAfterSchoolTheListIsTheNextOutingsBring() async {
        let monday = Day(year: 2026, month: 11, day: 16)
        let items = SeedData.items(today: tuesday, calendar: calendar).map { item -> ScheduleItem in
            guard item.title == "Swimming" else { return item }
            var swimming = item
            swimming.bring = [ItemMission(id: id("401"), name: "Goggles", picture: "goggles"),
                              ItemMission(id: id("402"), name: "Towel", picture: "towel")]
            return swimming
        }
        let store = store(on: monday, minute: 905, items: items)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.list(of: kidA).map(\.name), ["Goggles", "Towel"])
        XCTAssertEqual(store.state.outingEvent(of: kidA), .item(id("101")))
        XCTAssertEqual(store.state.list(of: kidB), [], "Kid B, at home with no outing, has no list (issue 024)")
    }
}

private extension MissionsFeature.State {
    func state(caption index: Int) -> String { caption(rows[index]) }
}
