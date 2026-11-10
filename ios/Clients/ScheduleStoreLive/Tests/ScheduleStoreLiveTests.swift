import ComposableArchitecture
import Domain
import Foundation
import ScheduleStore
import ScheduleStoreLive
import XCTest

final class ScheduleStoreLiveTests: XCTestCase {
    private var directory: URL!
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return calendar
    }()
    private let monday = Day(year: 2026, month: 11, day: 9)

    /// Every test runs with the app clock pinned to Monday 10:00 in Singapore.
    override func invokeTest() {
        withDependencies { [calendar, monday] in
            $0.calendar = calendar
            $0.date.now = monday.date(minute: 600, calendar: calendar)
        } operation: {
            super.invokeTest()
        }
    }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func store() -> ScheduleStore {
        ScheduleStore.live(directory: directory)
    }

    private func item(_ title: String, id: UUID = UUID()) -> ScheduleItem {
        ScheduleItem(id: id, title: title, iconName: "actSwim", audience: .kid(SeedData.kidA.id), start: 930,
                     end: 990, recurrence: .weekly([.monday], from: monday, until: nil), skippedDays: [],
                     skipsHolidays: true, showsStar: false)
    }

    /// A store with the sample family in it, as "Load sample family" leaves it.
    private func seeded() async throws -> ScheduleStore {
        let store = store()
        try await store.replaceFamily(ScheduleSnapshot.sampleFamily(today: monday, calendar: calendar))
        return store
    }

    /// The app starts empty and runs first-run setup (user, 2026-11-09).
    func testFirstLoadIsEmpty() async throws {
        let snapshot = try await store().load()
        XCTAssertEqual(snapshot, ScheduleSnapshot(kids: [], routines: [], items: []))
    }

    func testReplaceFamilyWritesEverythingAndDropsTheOldFamily() async throws {
        let store = try await seeded()
        try await store.saveSlide(OutingSlide(kid: SeedData.kidA.id, date: monday, outing: .school, ready: true))
        let kid = Kid(id: UUID(), name: "Kid C", colorIndex: 2, age: 6, schoolYear: nil, school: nil)
        let family = ScheduleSnapshot(
            kids: [kid], routines: StarterDays.routines(for: kid, trip: nil, from: monday), items: [],
            missions: StarterDays.missions(for: kid, id: { UUID() }),
            busPlans: [BusPlan(kid: kid.id, stop: "00000", services: ["1"])])
        try await store.replaceFamily(family)
        let loaded = try await self.store().load()   // a fresh store, like an app restart
        XCTAssertEqual(loaded.kids, family.kids)
        XCTAssertEqual(loaded.routines, family.routines)
        XCTAssertEqual(Set(loaded.missions), Set(family.missions))
        XCTAssertEqual(loaded.busPlans, family.busPlans)
        XCTAssertEqual(loaded.items, [])
        let slides = try await self.store().slides(SeedData.kidA.id, monday)
        XCTAssertEqual(slides, [], "old marks are gone")
    }

    func testSaveKidReplacesTheRecordInPlace() async throws {
        let store = try await seeded()
        var kidA = SeedData.kidA
        kidA.school?.latest = 465
        try await store.saveKid(kidA)
        let kids = try await self.store().load().kids
        XCTAssertEqual(kids, [kidA, SeedData.kidB])
    }

    func testSampleFamilyLoadsTheSeed() async throws {
        let snapshot = try await seeded().load()
        XCTAssertEqual(snapshot.kids, SeedData.kids)
        XCTAssertEqual(snapshot.routines, SeedData.routines)
        XCTAssertEqual(Set(snapshot.items), Set(SeedData.items(today: monday, calendar: calendar)))
    }

    /// G1 "This day" and "All days" on the same date are two records: neither replaces the other.
    func testADaysOwnTemplateKeepsItsOwnRecord() async throws {
        let kid = SeedData.kidA.id, day = Day(year: 2026, month: 11, day: 10)
        let block = RoutineBlock(title: "Play", iconName: "actPlay", kind: .play, start: 0, end: 1440)
        let all = Routine(kid: kid, dayType: .weekday, from: day, blocks: [block])
        let own = Routine.day(day, kid: kid, dayType: .weekday, blocks: [block])
        try await store().saveRoutine(all)
        try await store().saveRoutine(own)
        let routines = try await store().load().routines.filter { $0.from == day }
        XCTAssertEqual(Set(routines.map(\.onlyOn)), [nil, day])
    }

    func testSaveThenLoadInNewStoreKeepsItem() async throws {
        let swim = item("Pottery")
        try await seeded().save(swim)
        let reloaded = try await store().load()   // a new store on the same folder, like an app restart
        XCTAssertTrue(reloaded.items.contains(swim))
        XCTAssertEqual(reloaded.kids, SeedData.kids)
        XCTAssertEqual(reloaded.items.filter { $0.title == "Swimming" }.count, 1)
    }

    func testSaveSameIDReplaces() async throws {
        let id = UUID()
        let store = store()
        try await store.save(item("Pottery", id: id))
        try await store.save(item("Clay", id: id))
        let items = try await store.load().items.filter { $0.id == id }
        XCTAssertEqual(items.map(\.title), ["Clay"])
    }

    func testSaveAllWritesEveryItem() async throws {
        let store = store()
        let a = item("Old"), b = item("New")
        try await store.saveAll([a, b])
        let items = try await store.load().items
        XCTAssertTrue(items.contains(a))
        XCTAssertTrue(items.contains(b))
    }

    /// C2: one bus route a kid, replaced on save; made-up stop and buses (privacy rule).
    func testBusPlanSavesAndReplaces() async throws {
        let kid = SeedData.kidA.id
        try await store().saveBusPlan(BusPlan(kid: kid, stop: "00000", services: ["1"]))
        try await store().saveBusPlan(BusPlan(kid: kid, stop: "00000", services: ["1", "2"], walk: 8))
        let plans = try await store().load().busPlans
        XCTAssertEqual(plans, [BusPlan(kid: kid, stop: "00000", services: ["1", "2"], walk: 8)])
    }

    /// A slide per outing: School's and an item's are kept apart; the morning's (no outing) too.
    func testSlidesKeepEachOutingsTimeAndMedal() async throws {
        let date = Day(year: 2026, month: 11, day: 10)
        let school = OutingSlide(kid: SeedData.kidA.id, date: date, outing: .school, ready: true, readyAt: 418,
                                 medal: .gold)
        let swim = OutingSlide(kid: SeedData.kidA.id, date: date, outing: .item(UUID()), ready: true, readyAt: 950)
        let morning = OutingSlide(kid: SeedData.kidA.id, date: date, outing: nil, ready: true)
        for slide in [school, swim, morning] { try await store().saveSlide(slide) }
        let loaded = try await store().slides(SeedData.kidA.id, date)
        XCTAssertEqual(Set(loaded), [school, swim, morning])
        var again = school
        again.medal = .silver
        try await store().saveSlide(again)
        let replaced = try await store().slides(SeedData.kidA.id, date)
        XCTAssertEqual(Set(replaced), [again, swim, morning], "replaced, not added")
    }

    /// A route per event: School's replaces the old one; another event's is kept beside it.
    func testBusPlansPerEvent() async throws {
        let kid = SeedData.kidA.id
        try await store().saveBusPlan(BusPlan(kid: kid, stop: "00000", services: ["1"]))
        let swim = BusPlan(kid: kid, event: .item(UUID()), stop: "00001", services: ["2"])
        try await store().saveBusPlan(swim)
        try await store().saveBusPlan(BusPlan(kid: kid, stop: "00000", services: ["3"]))
        let plans = try await store().load().busPlans
        XCTAssertEqual(plans.count, 2)
        XCTAssertEqual(plans.route(kid: kid)?.services, ["3"])
        XCTAssertEqual(plans.route(kid: kid, event: swim.event), swim)
    }

    func testDeleteRemoves() async throws {
        let store = store()
        let pottery = item("Pottery")
        try await store.save(pottery)
        try await store.delete(pottery.id)
        let items = try await store.load().items
        XCTAssertFalse(items.contains { $0.id == pottery.id })
    }

    /// C6 "Save the day": a template saved from tomorrow leaves today on the old one.
    func testSavedTemplateStartsOnItsDay() async throws {
        let store = try await seeded()
        let old = try await store.load().routines.first { $0.kid == SeedData.kidA.id && $0.dayType == .weekday }!
        var new = old
        new.from = Day(year: 2026, month: 11, day: 10)
        new.blocks[1].end = 460
        new.blocks[2].start = 460
        try await store.saveRoutine(new)
        let routines = try await store.load().routines
        XCTAssertTrue(routines.contains(old))
        XCTAssertTrue(routines.contains(new))
        XCTAssertEqual(DayPlanner.template(for: SeedData.kidA.id, on: monday, routines: routines, holidays: [],
                                           calendar: calendar), old)
        XCTAssertEqual(DayPlanner.template(for: SeedData.kidA.id, on: new.from, routines: routines, holidays: [],
                                           calendar: calendar), new)
        // Saving again for the same day replaces it.
        new.blocks[1].end = 455
        new.blocks[2].start = 455
        try await store.saveRoutine(new)
        let again = try await self.store().load().routines   // a fresh store, like an app restart
        XCTAssertEqual(again.filter { $0.from == new.from && $0.kid == new.kid && $0.dayType == .weekday }, [new])
    }

    // MARK: Missions (spec "MVP data")

    func testSeedMissionsLoadAndASavedListReplacesTheKids() async throws {
        let store = try await seeded()
        let missions = try await store.load().missions
        XCTAssertEqual(Set(missions), Set(SeedData.missions))
        var kidA = missions.filter { $0.kid == SeedData.kidA.id }.sorted { $0.order < $1.order }
        kidA.removeLast()
        kidA.swapAt(0, 1)
        for index in kidA.indices { kidA[index].order = index }
        try await store.saveMissions(SeedData.kidA.id, kidA)
        let again = try await self.store().load().missions
        XCTAssertEqual(again.filter { $0.kid == SeedData.kidA.id }.sorted { $0.order < $1.order }.map(\.name),
                       ["Brush teeth", "Wake up", "Get dressed", "Breakfast", "Pack bag"])
        XCTAssertEqual(again.filter { $0.kid == SeedData.kidB.id }.count, 3, "Kid B untouched")
    }

    func testWindowMissionsRoundTripAndOldOnesAreDropped() async throws {
        let store = store()
        let empty = try await store.windowMissions(SeedData.kidA.id, monday, .morning)
        XCTAssertEqual(empty, WindowMissions(kid: SeedData.kidA.id, date: monday, window: .morning))
        let old = WindowMissions(kid: SeedData.kidA.id, date: monday.adding(days: -20, calendar: calendar),
                                 window: .morning, done: [UUID()])
        try await store.saveWindowMissions(old)
        let today = WindowMissions(kid: SeedData.kidA.id, date: monday, window: .morning, done: [SeedData.missions[0].id])
        let beforeSwim = WindowMissions(kid: SeedData.kidA.id, date: monday, window: .before(.item(UUID())), done: [UUID()])
        try await store.saveWindowMissions(today)
        try await store.saveWindowMissions(beforeSwim)
        let reloaded = self.store()
        let morning = try await reloaded.windowMissions(SeedData.kidA.id, monday, .morning)
        let before = try await reloaded.windowMissions(SeedData.kidA.id, monday, beforeSwim.window)
        XCTAssertEqual(morning, today)
        XCTAssertEqual(before, beforeSwim)
        let dropped = try await reloaded.windowMissions(SeedData.kidA.id, old.date, .morning)
        XCTAssertEqual(dropped.done, [], "older than 14 days")
    }

    func testCorruptFileThrowsAndKeepsFile() async throws {
        _ = try await store().load()
        let file = directory.appendingPathComponent(ScheduleStore.liveFileName)
        let garbage = Data("not a database".utf8)
        try garbage.write(to: file)
        do {
            _ = try await store().load()
            XCTFail("a corrupt store must not load as empty")
        } catch {}
        XCTAssertEqual(try Data(contentsOf: file), garbage, "the file is left for recovery")
    }
}
