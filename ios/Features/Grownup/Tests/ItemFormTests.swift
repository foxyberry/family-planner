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
        XCTAssertFalse(form.skipsHolidays, "off for an activity (spec: on when it follows School)")
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
        XCTAssertEqual(once.overlapCaption(items: [swim], kids: SeedData.kids, family: FamilyCalendar(), editing: nil,
                                           calendar: F.calendar),
                       "Overlaps Swimming 3:30–4:30 pm. This one shows on the clock then.")
    }

    func testOverlapCaptionWhenOtherWins() {
        let party = F.once("Party", on: Day(year: 2026, month: 11, day: 11), start: 900, end: 1080)
        XCTAssertEqual(form().overlapCaption(items: [party], kids: SeedData.kids, family: FamilyCalendar(), editing: nil,
                                             calendar: F.calendar),
                       "Party shows on the clock then.")
    }

    func testNoOverlapCaptionForEndedSeriesOrPastEvents() {
        let ended = F.weekly(until: Day(year: 2026, month: 11, day: 8))
        XCTAssertNil(form().overlapCaption(items: [ended], kids: SeedData.kids, family: FamilyCalendar(), editing: nil,
                                           calendar: F.calendar))
        let pastParty = F.once("Party", on: Day(year: 2026, month: 11, day: 4), start: 900, end: 1080)
        XCTAssertNil(form().overlapCaption(items: [pastParty], kids: SeedData.kids, family: FamilyCalendar(), editing: nil,
                                           calendar: F.calendar))
    }

    func testNoOverlapCaptionWithOwnOldHalfAfterSplit() {
        // The old half ends today; the new half (being edited) starts tomorrow.
        let old = F.weekly(until: F.monday)
        var newHalf = form()
        newHalf.date = Day(year: 2026, month: 11, day: 10)
        XCTAssertNil(newHalf.overlapCaption(items: [old], kids: SeedData.kids, family: FamilyCalendar(), editing: UUID(),
                                            calendar: F.calendar))
    }

    func testNoOverlapCaptionForOtherKidOrEditedItem() {
        let swimB = F.weekly(kid: SeedData.kidB)
        XCTAssertNil(form().overlapCaption(items: [swimB], kids: SeedData.kids, family: FamilyCalendar(), editing: nil,
                                           calendar: F.calendar))
        let swim = F.weekly()
        XCTAssertNil(form().overlapCaption(items: [swim], kids: SeedData.kids, family: FamilyCalendar(), editing: swim.id,
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
        XCTAssertFalse(weekly.skipsHolidays)
        XCTAssertEqual(weekly.runsEnd, RunsEnd.none)
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

    func testEachProblemShowsUnderItsRow() {
        XCTAssertEqual(FormProblem.noName.row, .name)
        XCTAssertEqual(FormProblem.endsBeforeStart.row, .when)
        XCTAssertEqual(FormProblem.timePassed.row, .when)
        XCTAssertEqual(FormProblem.noDay.row, .days)
    }

    // MARK: Preview (side column, boards C3, C4)

    private func preview(_ form: ItemForm, items: [ScheduleItem] = [], draftID: UUID? = UUID(),
                         showsDraft: Bool = true) -> FormPreview {
        form.preview(kids: SeedData.kids, routines: SeedData.routines, items: items, family: FamilyCalendar(), draftID: draftID,
                     showsDraft: showsDraft, today: F.monday, calendar: F.calendar)
    }

    func testPreviewHeadingForOneKidEveryWeek() {
        let monWed = preview(form())
        XCTAssertEqual(monWed.heading, "Kid A's Monday")
        XCTAssertNil(monWed.note)
        XCTAssertEqual(monWed.summary, "On the clock every Monday and Wednesday from 9 Nov.")
        XCTAssertEqual(preview(form(days: [.wednesday])).heading, "Kid A's Wednesday", "the next picked day")
    }

    func testPreviewHeadingForBothKids() {
        var both = form()
        both.audience = .both
        XCTAssertEqual(preview(both).heading, "Monday")
    }

    func testPreviewHeadingAndNoteJustOnce() {
        var once = form(repeats: .once)
        once.date = Day(year: 2026, month: 11, day: 12)
        let forKidA = preview(once)
        XCTAssertEqual(forKidA.heading, "Thursday 12 Nov")
        XCTAssertEqual(forKidA.note, "Just this day, for Kid A.")
        XCTAssertNil(forKidA.summary)
        once.audience = .both
        XCTAssertEqual(preview(once).note, "Just this day, for both kids.")
    }

    func testPreviewMarksOnlyTheDraftRowAndSkipsSleep() {
        let rows = preview(form(), items: [F.weekly("Reading", days: [.monday], start: 1000, end: 1040)]).rows
        XCTAssertEqual(rows.filter(\.isNew).map(\.slot.title), ["Pottery"])
        XCTAssertTrue(rows.contains { $0.slot.title == "Reading" && !$0.isNew })
        XCTAssertFalse(rows.contains { $0.slot.kind == .sleep })
        XCTAssertEqual(rows.first { $0.isNew }?.time, "3:30 pm")
    }

    func testPreviewLeavesOutADraftWithAProblem() {
        XCTAssertEqual(preview(form(), showsDraft: false).rows.filter(\.isNew), [])
        XCTAssertEqual(preview(form(), draftID: nil).rows.filter(\.isNew), [], "no id yet, no draft")
    }

    func testPreviewReplacesTheItemBeingEdited() {
        let swim = F.weekly(days: [.monday])
        var edited = ItemForm(item: swim)
        edited.name = "Swim club"
        let rows = preview(edited, items: [swim], draftID: swim.id).rows
        XCTAssertEqual(rows.filter(\.isNew).map(\.slot.title), ["Swim club"])
        XCTAssertFalse(rows.contains { $0.slot.title == "Swimming" })
    }

    func testPreviewWithoutKidsHasNoRows() {
        let empty = form().preview(kids: [], routines: [], items: [], family: FamilyCalendar(), draftID: UUID(), showsDraft: true,
                                   today: F.monday, calendar: F.calendar)
        XCTAssertEqual(empty.rows, [])
    }

    /// Board C3g: Going and Leave, and the preview line.
    func testGoingKeepsTheLeaveMinutesAndShowsTheLine() {
        var form = ItemForm(audience: .kid(SeedData.kidA.id), iconName: "actSwim", name: "Swimming", start: 990,
                            end: 1050, repeats: .weekly, days: [.wednesday], date: Day(year: 2026, month: 11, day: 11),
                            skipsHolidays: true, showsStar: true)
        XCTAssertNil(form.trip)
        form.setGoing(.car)
        XCTAssertEqual(form.trip, Trip(way: .car, leaveBefore: 10))
        form.stepLeave(1)
        XCTAssertEqual(form.leaveText, "15 min")
        XCTAssertEqual(form.leaveCaption, "before · 4:15 pm")
        XCTAssertEqual(form.leaveLine, "Leave 4:15 pm by car.")
        form.setGoing(.taxi)
        XCTAssertEqual(form.trip?.leaveBefore, 15)
        for _ in 0..<30 { form.stepLeave(1) }
        XCTAssertEqual(form.trip?.leaveBefore, 90)
        form.setGoing(nil)
        XCTAssertNil(form.leaveLine)
        XCTAssertEqual(form.item(id: UUID(), today: Day(year: 2026, month: 11, day: 9)).trip, nil)
    }

    /// Board C3 "What" (layout v6): the picked picture first, then the most used, then the kit's order.
    func testRowPicturesPutPickedThenMostUsed() {
        let all = ["actSwim", "actArt", "actMusic", "actPiano", "actDance", "actFootball", "cake"]
        XCTAssertEqual(ItemForm.rowPictures(picked: nil, used: [], all: all),
                       ["actSwim", "actArt", "actMusic", "actPiano", "actDance"])
        XCTAssertEqual(ItemForm.rowPictures(picked: "cake", used: ["actFootball", "actFootball", "actPiano"], all: all),
                       ["cake", "actFootball", "actPiano", "actSwim", "actArt"])
        // A picture outside the kit's list (a template slot) is not offered; no picture twice.
        XCTAssertEqual(ItemForm.rowPictures(picked: "actPiano", used: ["school", "actPiano"], all: all),
                       ["actPiano", "actSwim", "actArt", "actMusic", "actDance"])
    }

    // MARK: Event form rows (spec "Event form rows for 6b")

    private func choices(_ form: ItemForm, editing: ScheduleItem.ID? = nil) -> [String] {
        form.fromChoices(kids: SeedData.kids, routines: SeedData.routines,
                         items: SeedData.items(today: F.monday, calendar: F.calendar), editing: editing,
                         today: F.monday, calendar: F.calendar).map(\.title)
    }

    func testFromOffersHomeThenEventsThatEndBeforeTheStartOnEveryDay() {
        XCTAssertEqual(choices(form(start: 930, end: 990)), ["Home", "School"], "swimming ends after 3:30 pm")
        XCTAssertEqual(choices(form(start: 1020, end: 1080)), ["Home", "School", "Swimming"])
        XCTAssertEqual(choices(form(start: 1020, end: 1080, days: [.monday, .friday])), ["Home", "School"],
                       "swimming is not on Fridays")
        XCTAssertEqual(choices(form(start: 780, end: 840, days: [.saturday])), ["Home", "Weekend school"],
                       "no School on Saturday; weekend school ends at noon")
        XCTAssertEqual(choices(form(start: 600, end: 660)), ["Home"], "school ends at 3 pm")
    }

    func testAfterAnEventTheItemStartsAtItsEndKeepsItsLengthAndHasNoTrip() {
        var form = form(start: 930, end: 990)
        form.setGoing(.walk)
        let school = form.fromChoices(kids: SeedData.kids, routines: SeedData.routines, items: [], editing: nil,
                                      today: F.monday, calendar: F.calendar)[1]
        form.setFrom(school)
        XCTAssertEqual(form.after, .school)
        XCTAssertEqual(form.start, 900)
        XCTAssertEqual(form.end, 960)
        XCTAssertNil(form.trip)
        XCTAssertFalse(form.canSwitchMedal)
        let item = form.item(id: UUID(), today: F.monday)
        XCTAssertEqual(item.after, .school)
        XCTAssertNil(item.trip)
        XCTAssertEqual(choices(form), ["Home", "School"], "a linked item still offers its event")
    }

    func testMedalNeedsATripAndKeepsThroughWayChanges() {
        var form = form()
        form.toggleMedal()
        XCTAssertFalse(form.medalIsOn, "no trip, no medal")
        form.setGoing(.car)
        form.toggleMedal()
        XCTAssertTrue(form.medalIsOn)
        form.setGoing(.walk)
        form.stepLeave(1)
        XCTAssertTrue(form.medalIsOn, "the switch stays when the way or the leave time changes")
        XCTAssertEqual(form.item(id: UUID(), today: F.monday).trip?.medal, true)
    }

    func testBringTogglesUpToFourAndNamesThePictures() {
        var form = form()
        for (n, picture) in ["backpack", "lunchBox", "waterBottle", "towel", "goggles"].enumerated() {
            form.toggleBring(picture, id: UUID(uuidString: "00000000-0000-0000-0000-00000000000\(n)")!)
        }
        XCTAssertEqual(form.bring.map(\.picture), ["backpack", "lunchBox", "waterBottle", "towel"])
        XCTAssertEqual(form.bringText, "Backpack · Lunch box · Water bottle · Towel")
        form.toggleBring("lunchBox", id: UUID())
        XCTAssertEqual(form.bring.map(\.picture), ["backpack", "waterBottle", "towel"])
    }

    func testMissionsBeforeAndAfterAreListedForTheRow() {
        var form = form()
        XCTAssertNil(form.missionsText)
        let goggles = ItemMission(id: UUID(), name: "Goggles", picture: "goggles")
        let hang = ItemMission(id: UUID(), name: "Hang swimsuit", picture: "towel")
        form.saveMission(hang, in: .after)
        form.saveMission(goggles, in: .before)
        XCTAssertEqual(form.missionsText, "Goggles · Hang swimsuit (after)")
        var renamed = goggles
        renamed.name = "Pack goggles"
        form.saveMission(renamed, in: .before)
        XCTAssertEqual(form.missionsBefore.map(\.name), ["Pack goggles"])
        let shoes = ItemMission(id: UUID(), name: "Shoes on", picture: "shoe")
        form.saveMission(shoes, in: .before)
        form.moveMission(shoes.id, to: 0, in: .before)
        XCTAssertEqual(form.missionsBefore.map(\.name), ["Shoes on", "Pack goggles"])
        form.removeMission(hang.id)
        XCTAssertEqual(form.missionsAfter, [])
        let saved = form.item(id: UUID(), today: F.monday)
        XCTAssertEqual(ItemForm(item: saved).missionsBefore, form.missionsBefore)
    }

    // MARK: Runs (board G2)

    func testRunsEndsAreStoredAndShown() {
        var form = form()
        XCTAssertEqual(form.runsStartText(calendar: F.calendar), "9 Nov")
        XCTAssertEqual(form.runsEndText(calendar: F.calendar), "No end")
        form.runsEnd = .term
        XCTAssertEqual(form.runsEndText(calendar: F.calendar), "End of term")
        XCTAssertEqual(form.item(id: UUID(), today: F.monday).runsEnd, .term)
        XCTAssertEqual(form.item(id: UUID(), today: F.monday).recurrence,
                       .weekly([.monday, .wednesday], from: F.monday, until: nil), "worked out with the calendar")
        form.runsEnd = .date
        form.untilDate = Day(year: 2026, month: 12, day: 14)
        XCTAssertEqual(form.runsEndText(calendar: F.calendar), "14 Dec")
        XCTAssertEqual(form.item(id: UUID(), today: F.monday).recurrence,
                       .weekly([.monday, .wednesday], from: F.monday, until: Day(year: 2026, month: 12, day: 14)))
        form.runsEnd = .count
        form.stepTimes(-20)
        XCTAssertEqual(form.times, 1)
        XCTAssertEqual(form.runsEndText(calendar: F.calendar), "After 1 times")
        XCTAssertEqual(form.item(id: UUID(), today: F.monday).runsEnd, .count(1))
    }

    func testAnItemAfterSchoolSkipsSchoolHolidays() {
        var form = form()
        let school = form.fromChoices(kids: SeedData.kids, routines: SeedData.routines, items: [], editing: nil,
                                      today: F.monday, calendar: F.calendar)[1]
        form.setFrom(school)
        XCTAssertTrue(form.skipsHolidays)
    }

    func testEditingKeepsTheStoredEnd() {
        let item = ScheduleItem(id: UUID(), title: "Swim", iconName: "actSwim", audience: kidA, start: 930, end: 990,
                                recurrence: .weekly([.monday], from: F.monday, until: Day(year: 2026, month: 12, day: 7)),
                                skippedDays: [], skipsHolidays: true, showsStar: false)
        let form = ItemForm(item: item)
        XCTAssertEqual(form.runsEnd, .date, "an item saved before Runs with an end date")
        XCTAssertEqual(form.untilDate, Day(year: 2026, month: 12, day: 7))
    }
}
