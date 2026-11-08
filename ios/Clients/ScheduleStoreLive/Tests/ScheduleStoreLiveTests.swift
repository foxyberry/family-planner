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

    func testFirstLoadSeeds() async throws {
        let snapshot = try await store().load()
        XCTAssertEqual(snapshot.kids, SeedData.kids)
        XCTAssertEqual(snapshot.routines, SeedData.routines)
        XCTAssertEqual(Set(snapshot.items), Set(SeedData.items(today: monday, calendar: calendar)))
    }

    /// The first-run seed follows the app's clock (and so the developer time machine), not the device clock.
    func testSeedFollowsTheAppClock() async throws {
        let wednesday = Day(year: 2026, month: 11, day: 11)
        let snapshot = try await withDependencies { [calendar] in
            $0.date.now = wednesday.date(minute: 600, calendar: calendar)
        } operation: {
            try await store().load()
        }
        XCTAssertEqual(Set(snapshot.items), Set(SeedData.items(today: wednesday, calendar: calendar)))
    }

    func testSaveThenLoadInNewStoreKeepsItem() async throws {
        let swim = item("Pottery")
        try await store().save(swim)
        let reloaded = try await store().load()   // a new store on the same folder, like an app restart
        XCTAssertTrue(reloaded.items.contains(swim))
        XCTAssertEqual(reloaded.kids, SeedData.kids, "seeding happens once")
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
        let store = store()
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
        let store = store()
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

    func testMissionDayRoundTripsAndOldDaysAreDropped() async throws {
        let store = store()
        let empty = try await store.missionDay(SeedData.kidA.id, monday)
        XCTAssertEqual(empty, MissionDay(kid: SeedData.kidA.id, date: monday))
        let old = MissionDay(kid: SeedData.kidA.id, date: monday.adding(days: -20, calendar: calendar), done: [UUID()])
        try await store.saveMissionDay(old)
        let today = MissionDay(kid: SeedData.kidA.id, date: monday, done: [SeedData.missions[0].id], ready: true)
        try await store.saveMissionDay(today)
        let reloaded = self.store()
        let loaded = try await reloaded.missionDay(SeedData.kidA.id, monday)
        XCTAssertEqual(loaded, today)
        let dropped = try await reloaded.missionDay(SeedData.kidA.id, old.date)
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
