import ComposableArchitecture
import Domain
import Foundation
import ScheduleStore
import ScheduleStoreLive
import SwiftData
import XCTest

/// The same shape as the live store's record, so a test can write a store the way an older app did.
@Model
final class StoredRecord {
    @Attribute(.unique) var key: String
    var group: String
    var order: Int
    var payload: Data

    init(key: String, group: String, order: Int, payload: Data) {
        self.key = key
        self.group = group
        self.order = order
        self.payload = payload
    }
}

final class OldSeedTests: XCTestCase {
    private var directory: URL!
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return calendar
    }()
    private let monday = Day(year: 2026, month: 11, day: 9)

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

    /// Writes records straight into the store file, as an older build of the app left them.
    private func writeStore(seedVersion: Int?, routinePayload: String) throws {
        let url = directory.appendingPathComponent(ScheduleStore.liveFileName)
        let container = try ModelContainer(for: StoredRecord.self, configurations: ModelConfiguration(url: url))
        let context = ModelContext(container)
        let kid = try JSONEncoder().encode(SeedData.kidA)
        context.insert(StoredRecord(key: "kid:\(SeedData.kidA.id)", group: "kid", order: 0, payload: kid))
        context.insert(StoredRecord(key: "routine:old", group: "routine", order: 0, payload: Data(routinePayload.utf8)))
        let pottery = ScheduleItem(id: UUID(), title: "Pottery", iconName: "actArt", audience: .kid(SeedData.kidA.id),
                                   start: 930, end: 990, recurrence: .weekly([.monday], from: monday, until: nil),
                                   skippedDays: [], skipsHolidays: true, showsStar: false)
        context.insert(StoredRecord(key: "item:\(pottery.id)", group: "item", order: 0,
                                    payload: try JSONEncoder().encode(pottery)))
        if let seedVersion {
            context.insert(StoredRecord(key: "meta:seeded", group: "meta", order: 0,
                                        payload: try JSONEncoder().encode(seedVersion)))
        }
        try context.save()
    }

    /// A routine as the first seed stored it: a school-day / day-off kind and no day type or start day.
    private var oldRoutineJSON: String {
        #"{"kid":"\#(SeedData.kidA.id)","dayKind":"schoolDay","blocks":[]}"#
    }

    /// An older build's seed is never wiped (user, 2026-11-09: no data lost without asking); its
    /// routines in the first shape are skipped and the rest loads.
    func testOldSeedIsKeptAndOldRoutinesAreSkipped() async throws {
        try writeStore(seedVersion: 1, routinePayload: oldRoutineJSON)
        let snapshot = try await ScheduleStore.live(directory: directory).load()
        XCTAssertEqual(snapshot.kids, [SeedData.kidA])
        XCTAssertEqual(snapshot.items.map(\.title), ["Pottery"])
        XCTAssertEqual(snapshot.routines, [])
    }

    func testCurrentSeedVersionKeepsUserItems() async throws {
        let routine = String(decoding: try JSONEncoder().encode(SeedData.routines[0]), as: UTF8.self)
        try writeStore(seedVersion: SeedData.version, routinePayload: routine)
        let snapshot = try await ScheduleStore.live(directory: directory).load()
        XCTAssertEqual(snapshot.items.map(\.title), ["Pottery"])
        XCTAssertEqual(snapshot.routines, [SeedData.routines[0]])
    }
}
