import Domain
import Foundation
import Grownup
import ScheduleStore
import XCTest

final class ItemFormTests: XCTestCase {
    private typealias F = Fixture
    private let kidA = Audience.kid(SeedData.kidA.id)

    private func form(start: Int = 930, end: Int = 990, days: Set<Weekday> = [.monday, .wednesday],
                      repeats: ItemForm.Repeat = .weekly, name: String = "Pottery") -> ItemForm {
        var form = ItemForm.defaults(audience: kidA, now: F.monday.date(minute: 600, calendar: F.calendar),
                                     calendar: F.calendar)
        form.name = name
        form.iconName = "actArt"
        form.start = start
        form.end = end
        form.days = days
        form.repeats = repeats
        return form
    }

    func testDefaults() {
        let form = ItemForm.defaults(audience: kidA, now: F.monday.date(minute: 9 * 60 + 24, calendar: F.calendar),
                                     calendar: F.calendar)
        XCTAssertEqual(form.audience, kidA)
        XCTAssertNil(form.iconName)
        XCTAssertEqual(form.name, "")
        XCTAssertEqual(form.start, 600)
        XCTAssertEqual(form.end, 660)
        XCTAssertEqual(form.repeats, .weekly)
        XCTAssertEqual(form.days, [.monday])
        XCTAssertEqual(form.date, F.monday)
        XCTAssertTrue(form.skipsHolidays)
        XCTAssertTrue(form.showsStar)
    }

    func testDefaultsLateEveningStayInTheDay() {
        let form = ItemForm.defaults(audience: kidA, now: F.monday.date(minute: 23 * 60 + 30, calendar: F.calendar),
                                     calendar: F.calendar)
        XCTAssertEqual(form.start, 1380)
        XCTAssertEqual(form.end, 1440)
    }

    func testPictureFillsEmptyNameOnly() {
        var empty = form(name: "")
        empty.pickPicture("actSwim")
        XCTAssertEqual(empty.name, "Swim")
        XCTAssertEqual(empty.iconName, "actSwim")
        var typed = form(name: "Pool time")
        typed.pickPicture("actSwim")
        XCTAssertEqual(typed.name, "Pool time")
    }

    func testValidationOrder() {
        let today = F.monday
        XCTAssertEqual(form(start: 990, end: 930, days: [], name: " ").problem(today: today, nowMinute: 600)?.message,
                       "Give it a name")
        XCTAssertEqual(form(start: 990, end: 930, days: []).problem(today: today, nowMinute: 600)?.message,
                       "Ends before it starts")
        XCTAssertEqual(form(days: []).problem(today: today, nowMinute: 600)?.message, "Pick at least one day")
        var once = form(start: 540, end: 600, repeats: .once)
        once.date = today
        XCTAssertEqual(once.problem(today: today, nowMinute: 600)?.message, "That time has passed")
        XCTAssertNil(form().problem(today: today, nowMinute: 600))
    }

    func testDurationCaption() {
        XCTAssertEqual(form(start: 930, end: 990).durationCaption, "1 hour")
        XCTAssertEqual(form(start: 930, end: 1020).durationCaption, "1 hr 30 min")
        XCTAssertNil(form(start: 990, end: 930).durationCaption)
    }

    func testOverlapCaptionWhenNewWins() {
        let swim = F.weekly()   // Mon · Wed 3:30–4:30 every week
        var once = form(start: 960, end: 1020, repeats: .once)
        once.date = F.monday
        XCTAssertEqual(once.overlapCaption(items: [swim], kids: SeedData.kids, holidays: [], editing: nil,
                                           calendar: F.calendar),
                       "Overlaps Swimming 3:30–4:30. This one shows on the clock then.")
    }

    func testOverlapCaptionWhenOtherWins() {
        let party = F.once("Party", on: Day(year: 2026, month: 11, day: 11), start: 900, end: 1080)
        XCTAssertEqual(form().overlapCaption(items: [party], kids: SeedData.kids, holidays: [], editing: nil,
                                             calendar: F.calendar),
                       "Party shows on the clock then.")
    }

    func testNoOverlapCaptionForOtherKidOrEditedItem() {
        let swimB = F.weekly(kid: SeedData.kidB)
        XCTAssertNil(form().overlapCaption(items: [swimB], kids: SeedData.kids, holidays: [], editing: nil,
                                           calendar: F.calendar))
        let swim = F.weekly()
        XCTAssertNil(form().overlapCaption(items: [swim], kids: SeedData.kids, holidays: [], editing: swim.id,
                                           calendar: F.calendar))
    }

    func testSummaryCaption() {
        XCTAssertEqual(form().summaryCaption(today: F.monday, calendar: F.calendar),
                       "On the clock every Monday and Wednesday from 9 Nov.")
        XCTAssertEqual(form(days: Weekday.schoolDays).summaryCaption(today: F.monday, calendar: F.calendar),
                       "On the clock every school day from 9 Nov.")
    }

    func testItemFromForm() {
        let id = UUID()
        let weekly = form().item(id: id, today: F.monday)
        XCTAssertEqual(weekly.recurrence, .weekly([.monday, .wednesday], from: F.monday, until: nil))
        XCTAssertTrue(weekly.skipsHolidays)
        XCTAssertFalse(weekly.showsStar)
        var onceForm = form(repeats: .once)
        onceForm.date = F.monday.adding(days: 3, calendar: F.calendar)
        let once = onceForm.item(id: id, today: F.monday)
        XCTAssertEqual(once.recurrence, .once(Day(year: 2026, month: 11, day: 12)))
        XCTAssertFalse(once.skipsHolidays)
        XCTAssertTrue(once.showsStar)
        let back = ItemForm(item: once)
        XCTAssertEqual([back.name, back.iconName], [onceForm.name, onceForm.iconName])
        XCTAssertEqual([back.start, back.end], [onceForm.start, onceForm.end])
        XCTAssertEqual(back.repeats, .once)
        XCTAssertEqual(back.date, onceForm.date)
        XCTAssertEqual(back.audience, onceForm.audience)
    }
}
