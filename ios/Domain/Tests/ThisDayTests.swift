import Domain
import XCTest

/// Spec "Repeats, dates and changes": This day (a day changed on its own) and All days ("Change from
/// when?" splits the series; changed days that no longer fit are dropped).
final class ThisDayTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return calendar
    }()
    private let kid = Kid(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!, name: "Kid A", colorIndex: 0,
                          age: 8, schoolYear: nil, school: nil)
    private let id = UUID(uuidString: "00000000-0000-0000-0000-00000000C001")!
    private let newID = UUID(uuidString: "00000000-0000-0000-0000-00000000C002")!
    private func day(_ d: Int) -> Day { Day(year: 2026, month: 11, day: d) }

    /// Swimming on Mondays and Wednesdays from 2 Nov, 3:30–4:30 pm.
    private func swimming(days: Set<Weekday> = [.monday, .wednesday]) -> ScheduleItem {
        ScheduleItem(id: id, title: "Swimming", iconName: "actSwim", audience: .kid(kid.id), start: 930, end: 990,
                     recurrence: .weekly(days, from: day(2), until: nil), skippedDays: [], skipsHolidays: false,
                     showsStar: false)
    }

    func testThisDayChangesOnlyThatDay() {
        var edit = swimming()
        edit.start = 960
        edit.end = 1020
        let changed = SeriesEdits.changing(swimming(), on: day(16), to: edit)
        XCTAssertEqual(changed.dayChanges, [DayChange(day: day(16), start: 960, end: 1020)])
        let slots = { (d: Int) in
            DayPlanner.slots(on: self.day(d), kid: self.kid, routines: [], items: [changed], holidays: [],
                             calendar: self.calendar).filter { $0.title == "Swimming" }.map(\.start)
        }
        XCTAssertEqual(slots(16), [960])
        XCTAssertEqual(slots(18), [930], "Wednesday keeps the series' time")
        XCTAssertEqual(SeriesEdits.changing(changed, on: day(16), to: swimming()).dayChanges, [],
                       "changed back to the series: no change left")
    }

    func testAllDaysFromADaySplitsTheSeriesAndDropsDaysThatNoLongerFit() {
        var original = swimming()
        original.skippedDays = [day(4), day(18)]
        original.dayChanges = [DayChange(day: day(16), start: 960), DayChange(day: day(23), start: 960)]
        var edit = swimming(days: [.wednesday])
        edit.recurrence = .weekly([.wednesday], from: day(10), until: nil)
        let split = SeriesEdits.splitting(original, with: edit, from: day(11), newID: newID, calendar: calendar)
        XCTAssertEqual(split.items.count, 2)
        XCTAssertEqual(split.items[0].recurrence, .weekly([.monday, .wednesday], from: day(2), until: day(10)))
        XCTAssertEqual(split.items[0].skippedDays, [day(4)], "days before stay with the old part")
        XCTAssertEqual(split.items[1].id, newID)
        XCTAssertEqual(split.items[1].recurrence, .weekly([.wednesday], from: day(11), until: nil))
        XCTAssertEqual(split.items[1].skippedDays, [day(18)], "a Wednesday still fits")
        XCTAssertEqual(split.items[1].dayChanges, [])
        XCTAssertEqual(split.removed, [day(16), day(23)], "the changed Mondays no longer fit")
    }

    func testAllDaysFromTheStartChangesTheWholeSeriesInPlace() {
        var edit = swimming()
        edit.start = 900
        let split = SeriesEdits.splitting(swimming(), with: edit, from: day(2), newID: newID, calendar: calendar)
        XCTAssertEqual(split.items.map(\.id), [id])
        XCTAssertEqual(split.items.first?.start, 900)
        XCTAssertEqual(split.items.first?.recurrence, .weekly([.monday, .wednesday], from: day(2), until: nil))
    }

    func testOldItemsLoadWithoutDayChanges() throws {
        let data = try JSONEncoder().encode(swimming())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["dayChanges"] = nil
        let item = try JSONDecoder().decode(ScheduleItem.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(item.dayChanges, [])
    }
}
