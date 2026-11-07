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

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func store() -> ScheduleStore {
        ScheduleStore.live(directory: directory, calendar: calendar,
                           now: { [calendar, monday] in monday.date(minute: 600, calendar: calendar) })
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
