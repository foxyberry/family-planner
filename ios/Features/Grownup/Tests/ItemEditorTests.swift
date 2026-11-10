import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import Grownup
import HolidayProvider
import ScheduleStore
import SchoolDirectory
import XCTest

@MainActor
final class ItemEditorTests: XCTestCase {
    private typealias F = Fixture
    private let kidA = Audience.kid(SeedData.kidA.id)

    private func store(mode: ItemEditorFeature.Mode, repeats: ItemForm.Repeat = .weekly, items: [ScheduleItem] = [],
                       saved: LockIsolated<[ScheduleItem]> = .init([]), deleted: LockIsolated<[UUID]> = .init([]),
                       saveError: Bool = false, school: SchoolCalendar = .none) -> TestStoreOf<ItemEditorFeature> {
        let now = F.monday.date(minute: 600, calendar: F.calendar)
        let snapshot = F.snapshot(items: items)
        let store = TestStore(initialState: ItemEditorFeature.State(mode: mode, repeats: repeats, now: now,
                                                                    calendar: F.calendar)) {
            ItemEditorFeature()
        } withDependencies: {
            $0.calendar = F.calendar
            $0.date.now = now
            $0.uuid = .incrementing
            $0.scheduleStore.load = { snapshot }
            $0.scheduleStore.save = { item in
                if saveError { throw CocoaError(.fileWriteUnknown) }
                saved.withValue { $0.append(item) }
            }
            $0.scheduleStore.delete = { id in deleted.withValue { $0.append(id) } }
            $0.holidays.holidays = { _ in [] }
            $0.schoolDirectory.calendar = { _, _ in school }
        }
        store.exhaustivity = .off
        return store
    }

    private func fill(_ store: TestStoreOf<ItemEditorFeature>) async {
        await store.send(.picturePicked("actArt"))
        await store.send(.binding(.set(\.form.start, 930)))
        await store.send(.binding(.set(\.form.end, 990)))
    }

    func testAddWeeklySavesAndFinishes() async {
        let saved = LockIsolated<[ScheduleItem]>([])
        let store = store(mode: .add(kidA), saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await fill(store)
        XCTAssertEqual(store.state.form.name, "Art")
        await store.send(.saveTapped)
        await store.receive(\.saved)
        await store.receive(\.delegate.finished)
        XCTAssertEqual(saved.value.map(\.title), ["Art"])
        XCTAssertEqual(saved.value.first?.recurrence, .weekly([.monday], from: F.monday, until: nil))
    }

    func testSaveIsBlockedWhileTheFormHasAProblem() async {
        let saved = LockIsolated<[ScheduleItem]>([])
        let store = store(mode: .add(kidA), saved: saved)
        XCTAssertEqual(store.state.problem?.message, "Give it a name")
        await store.send(.saveTapped)
        XCTAssertEqual(saved.value, [])
    }

    func testSwitchToJustOnceKeepsForWhatNameWhen() async {
        let store = store(mode: .add(kidA))
        await fill(store)
        await store.send(.repeatChanged(.once))
        XCTAssertEqual(store.state.form.repeats, .once)
        XCTAssertEqual(store.state.form.name, "Art")
        XCTAssertEqual(store.state.form.iconName, "actArt")
        XCTAssertEqual([store.state.form.start, store.state.form.end], [930, 990])
        XCTAssertEqual(store.state.form.audience, kidA)
    }

    func testBackWithChangesAsksLeaveWithoutAdding() async {
        let store = store(mode: .add(kidA))
        await fill(store)
        await store.send(.backTapped)
        XCTAssertEqual(store.state.confirm, .leave)
        XCTAssertEqual(store.state.confirmTitle, "Leave without adding?")
        await store.send(.confirmCancelled)
        XCTAssertNil(store.state.confirm)
        await store.send(.backTapped)
        await store.send(.confirmAccepted)
        await store.receive(\.delegate.finished)
    }

    func testBackWithoutChangesLeavesAtOnce() async {
        let store = store(mode: .add(kidA))
        await store.send(.backTapped)
        await store.receive(\.delegate.finished)
        XCTAssertNil(store.state.confirm)
    }

    func testSaveFailureKeepsFormAndShowsCaption() async {
        let store = store(mode: .add(kidA), saveError: true)
        await fill(store)
        await store.send(.saveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(store.state.saveError, "Couldn't save. Try again.")
        XCTAssertEqual(store.state.form.name, "Art")
    }

    func testDateChipsShowFiveFromTodayAndPageByWeek() async {
        let store = store(mode: .add(kidA), repeats: .once)
        XCTAssertEqual(store.state.visibleDates.first, F.monday)
        XCTAssertEqual(store.state.visibleDates.count, 5)
        await store.send(.datePageTapped(-1))
        XCTAssertEqual(store.state.visibleDates.first, F.monday, "past dates are not shown")
        await store.send(.datePageTapped(1))
        XCTAssertEqual(store.state.visibleDates.first, Day(year: 2026, month: 11, day: 16))
    }

    func testDoubleTapSavesOnce() async {
        let saved = LockIsolated<[ScheduleItem]>([])
        let store = store(mode: .add(kidA), saved: saved)
        await fill(store)
        await store.send(.saveTapped)
        await store.send(.saveTapped)
        await store.finish()
        XCTAssertEqual(saved.value.count, 1)
    }

    func testSaveRetryAfterFailureSaves() async {
        let fail = LockIsolated(true)
        let saved = LockIsolated<[ScheduleItem]>([])
        let now = F.monday.date(minute: 600, calendar: F.calendar)
        let store = TestStore(initialState: ItemEditorFeature.State(mode: .add(kidA), now: now, calendar: F.calendar)) {
            ItemEditorFeature()
        } withDependencies: {
            $0.calendar = F.calendar
            $0.date.now = now
            $0.uuid = .incrementing
            $0.scheduleStore.save = { item in
                if fail.value { throw CocoaError(.fileWriteUnknown) }
                saved.withValue { $0.append(item) }
            }
        }
        store.exhaustivity = .off
        await fill(store)
        await store.send(.saveTapped)
        await store.receive(\.saved)
        fail.setValue(false)
        await store.send(.saveTapped)
        await store.receive(\.saved)
        await store.receive(\.delegate.finished)
        XCTAssertEqual(saved.value.count, 1)
    }

    func testDeleteFailureStaysAndSaysSo() async {
        let party = F.once("Party", on: Day(year: 2026, month: 11, day: 14))
        let now = F.monday.date(minute: 600, calendar: F.calendar)
        let store = TestStore(initialState: ItemEditorFeature.State(mode: .editOnce(party), now: now,
                                                                    calendar: F.calendar)) {
            ItemEditorFeature()
        } withDependencies: {
            $0.calendar = F.calendar
            $0.date.now = now
            $0.scheduleStore.delete = { _ in throw CocoaError(.fileWriteUnknown) }
        }
        store.exhaustivity = .off
        await store.send(.removeTapped)
        await store.send(.confirmAccepted)
        await store.receive(\.saved)
        XCTAssertEqual(store.state.saveError, "Couldn't save. Try again.")
    }

    func testEditingARunningEventIsAllowed() {
        // Party 8:00–10:00 pm today; at 9:00 pm a grown-up stretches it to 11:00.
        let party = F.once("Party", on: F.monday, start: 1200, end: 1320)
        var state = ItemEditorFeature.State(mode: .editOnce(party), now: F.monday.date(minute: 1260, calendar: F.calendar),
                                            calendar: F.calendar)
        state.form.end = 1380
        XCTAssertNil(state.problem)
        state.form.start = 1230
        XCTAssertEqual(state.problem, .timePassed, "moving the start into the past is still blocked")
    }

    func testEditOnceRemoveAsksAndDeletes() async {
        let party = F.once("Party", on: Day(year: 2026, month: 11, day: 14))
        let deleted = LockIsolated<[UUID]>([])
        let store = store(mode: .editOnce(party), items: [party], deleted: deleted)
        XCTAssertEqual(store.state.title, "Edit Party")
        await store.send(.removeTapped)
        XCTAssertEqual(store.state.confirm, .removeOnce)
        XCTAssertEqual(store.state.confirmTitle, "Remove Party?")
        XCTAssertEqual(store.state.confirmMessage, "It leaves the clock on Saturday 14 Nov.")
        await store.send(.confirmAccepted)
        await store.receive(\.removed)
        await store.receive(\.delegate.finished)
        XCTAssertEqual(deleted.value, [party.id])
    }

    // MARK: State the view renders

    func testAudienceTabsOfferBothOnlyForTwoKids() async {
        let store = store(mode: .add(kidA))
        XCTAssertEqual(store.state.audienceTabs, [], "no kids before loading")
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.audienceTabs, [
            .init(audience: kidA, title: "Kid A", badge: .init(face: "kidGirl", colorIndex: 0)),
            .init(audience: .kid(SeedData.kidB.id), title: "Kid B", badge: .init(face: "kidBoy", colorIndex: 1)),
            .init(audience: .both, title: "Both", badge: nil),
        ])
        var oneKid = store.state
        oneKid.snapshot = ScheduleSnapshot(kids: [SeedData.kidA], routines: SeedData.routines, items: [])
        XCTAssertEqual(oneKid.audienceTabs.map(\.title), ["Kid A"])
    }

    func testAudienceTapSetsWhoItIsFor() async {
        let store = store(mode: .add(kidA), saveError: true)
        await fill(store)
        await store.send(.saveTapped)
        await store.receive(\.saved)
        await store.send(.audienceTapped(.both))
        XCTAssertEqual(store.state.form.audience, .both)
        XCTAssertNil(store.state.saveError, "a change clears the old save error")
    }

    func testCanSaveFollowsProblemAndSaving() async {
        let store = store(mode: .add(kidA))
        XCTAssertFalse(store.state.canSave, "no name yet")
        await fill(store)
        XCTAssertTrue(store.state.canSave)
        await store.send(.saveTapped)
        XCTAssertFalse(store.state.canSave, "already saving")
    }

    func testConfirmLabels() async {
        let party = F.once("Party", on: Day(year: 2026, month: 11, day: 14))
        let store = store(mode: .editOnce(party), items: [party])
        await store.send(.binding(.set(\.form.name, "Big party")))
        await store.send(.backTapped)
        XCTAssertEqual([store.state.confirmCancelTitle, store.state.confirmAcceptTitle], ["Keep editing", "Leave"])
        XCTAssertFalse(store.state.confirmIsDestructive)
        await store.send(.confirmCancelled)
        await store.send(.removeTapped)
        XCTAssertEqual([store.state.confirmCancelTitle, store.state.confirmAcceptTitle], ["Keep", "Remove"])
        XCTAssertTrue(store.state.confirmIsDestructive)
    }

    func testProblemShowsUnderItsRowOnly() async {
        let store = store(mode: .add(kidA))
        XCTAssertNil(store.state.problem(for: .name), "board C3: no warning before the first change")
        XCTAssertFalse(store.state.canSave)
        await store.send(.binding(.set(\.form.name, " ")))
        XCTAssertEqual(store.state.problem(for: .name), .noName)
        XCTAssertNil(store.state.problem(for: .when))
        await fill(store)
        await store.send(.binding(.set(\.form.end, 900)))
        XCTAssertNil(store.state.problem(for: .name))
        XCTAssertEqual(store.state.problem(for: .when), .endsBeforeStart)
        XCTAssertNil(store.state.problem(for: .days))
    }

    func testDateChipsNameTheWeekdayAndPageEarlierOnlyAfterPagingOn() async {
        let store = store(mode: .add(kidA), repeats: .once)
        XCTAssertEqual(store.state.dateChips.map(\.weekday), ["Mon", "Tue", "Wed", "Thu", "Fri"])
        XCTAssertEqual(store.state.dateChips.map(\.day), store.state.visibleDates)
        XCTAssertEqual(store.state.dateChips.map(\.isOn), [true, false, false, false, false])
        XCTAssertFalse(store.state.canPageEarlier)
        await store.send(.datePageTapped(1))
        XCTAssertTrue(store.state.canPageEarlier)
        XCTAssertEqual(store.state.dateChips.map(\.isOn), [false, false, false, false, false])
    }

    func testDayToggledAddsAndRemovesADay() async {
        let store = store(mode: .add(kidA))
        await store.send(.dayToggled(.wednesday))
        XCTAssertEqual(store.state.form.days, [.monday, .wednesday])
        await store.send(.dayToggled(.monday))
        XCTAssertEqual(store.state.form.days, [.wednesday])
    }

    func testTimePickedSetsMinutesOfTheDay() async {
        let store = store(mode: .add(kidA))
        await store.send(.startPicked(F.monday.date(minute: 945, calendar: F.calendar)))
        await store.send(.endPicked(F.monday.date(minute: 1005, calendar: F.calendar)))
        XCTAssertEqual([store.state.form.start, store.state.form.end], [945, 1005])
        XCTAssertEqual(store.state.startTime, F.monday.date(minute: 945, calendar: F.calendar))
        XCTAssertEqual(store.state.endTime, F.monday.date(minute: 1005, calendar: F.calendar))
        XCTAssertEqual([store.state.startLabel, store.state.endLabel], ["3:45 pm", "4:45 pm"])
    }

    func testNowMinuteUsesTheCalendar() {
        let state = ItemEditorFeature.State(mode: .add(kidA), now: F.monday.date(minute: 615, calendar: F.calendar),
                                            calendar: F.calendar)
        XCTAssertEqual(state.nowMinute, 615)
    }

    func testPreviewMarksTheDraftWithItsOwnID() async throws {
        let swim = F.weekly(days: [.wednesday])
        let store = store(mode: .add(kidA), items: [swim])
        await store.send(.task)
        await store.receive(\.loaded)
        let draftID = try XCTUnwrap(store.state.draftID)
        XCTAssertNotEqual(draftID, swim.id)
        XCTAssertEqual(store.state.preview?.rows.filter(\.isNew), [], "no draft while the form has a problem")
        await fill(store)
        XCTAssertEqual(store.state.preview?.heading, "Kid A's Monday")
        XCTAssertEqual(store.state.preview?.rows.filter(\.isNew).map(\.slot.title), ["Art"])
        XCTAssertEqual(store.state.preview?.rows.filter(\.isNew).first?.slot.source, .weekly(draftID))
    }

    func testAddingShowsThePreviewColumn() {
        let store = store(mode: .add(kidA))
        XCTAssertFalse(store.state.isEditingWeekly)
        XCTAssertNotNil(store.state.preview)
    }

    /// "More" opens every picture; picking one closes it and puts it first in the row.
    func testMorePicturesPickFirstInTheRow() async {
        let store = store(mode: .add(.kid(SeedData.kidA.id)))
        store.exhaustivity = .off
        await store.send(.morePicturesTapped) { $0.isPickingMorePictures = true }
        await store.send(.picturePicked("cake")) { $0.isPickingMorePictures = false }
        XCTAssertEqual(store.state.whatRow.first, "cake")
        XCTAssertEqual(store.state.whatRow.count, 5)
    }

    // MARK: Event form rows (spec "Event form rows for 6b")

    func testFromAfterSchoolLinksTheItemAndHidesItsTrip() async {
        let saved = LockIsolated<[ScheduleItem]>([])
        let store = store(mode: .add(kidA), saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await fill(store)
        await store.send(.goingTapped(.walk))
        XCTAssertEqual(store.state.fromText, "Home")
        await store.send(.fromRowTapped)
        XCTAssertEqual(store.state.card, .from)
        XCTAssertEqual(store.state.fromCircles.map(\.caption), ["Home", "School"])
        await store.send(.fromPicked("school"))
        XCTAssertEqual(store.state.card, .from, "open for the minutes after")
        await store.send(.cardClosed)
        XCTAssertEqual(store.state.fromText, "After School")
        XCTAssertEqual(store.state.linkedStartText, "after School")
        XCTAssertEqual(store.state.form.start, 900)
        XCTAssertNil(store.state.form.trip)
        await store.send(.saveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(saved.value.first?.after, .school)
    }

    func testBringCardPicksUpToFourAndATapOutsidePutsTheListBack() async {
        let store = store(mode: .add(kidA))
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.bringRowTapped)
        await store.send(.bringToggled(.backpack))
        await store.send(.bringToggled(.waterBottle))
        await store.send(.bringDoneTapped)
        XCTAssertEqual(store.state.form.bringText, "Backpack · Water bottle")
        await store.send(.bringRowTapped)
        await store.send(.bringMoreTapped)
        XCTAssertGreaterThan(store.state.bringSlots.count, 3)
        await store.send(.bringToggled(.lunchBox))
        await store.send(.cardClosed)
        XCTAssertEqual(store.state.form.bring.map(\.picture), ["backpack", "waterBottle"])
    }

    func testMissionsPageAddsEditsAndRemovesBeforeAndAfterMissions() async {
        let store = store(mode: .add(kidA))
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.missionsRowTapped)
        XCTAssertTrue(store.state.isEditingMissions)
        await store.send(.missionAddTapped(.after))
        await store.send(.missionNameChanged("Hang swimsuit"))
        await store.send(.missionPicturePicked("shirt"))
        await store.send(.missionSaveTapped)
        await store.send(.missionAddTapped(.before))
        await store.send(.missionNameChanged("Goggles"))
        await store.send(.missionSaveTapped)
        XCTAssertEqual(store.state.form.missionsText, "Goggles · Hang swimsuit (after)")
        let goggles = store.state.form.missionsBefore[0].id
        await store.send(.missionRowTapped(goggles))
        await store.send(.missionRemoveTapped)
        XCTAssertEqual(store.state.missionRemoveTitle, "Remove Goggles?")
        await store.send(.missionRemoveConfirmed)
        XCTAssertEqual(store.state.form.missionsBefore, [])
        await store.send(.missionsBackTapped)
        XCTAssertFalse(store.state.isEditingMissions)
    }

    func testMedalSwitchNeedsATrip() async {
        let store = store(mode: .add(kidA))
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.medalToggled)
        XCTAssertFalse(store.state.form.medalIsOn)
        await store.send(.goingTapped(.car))
        await store.send(.medalToggled)
        XCTAssertTrue(store.state.form.medalIsOn)
    }

    // MARK: Runs (board G2)

    func testRunsEndOfTermByDefaultAndTheCardPutsItBackOnATapOutside() async {
        let term = SchoolCalendar.Term(name: "Term 4", start: Day(year: 2026, month: 9, day: 14),
                                       end: Day(year: 2026, month: 11, day: 20))
        let saved = LockIsolated<[ScheduleItem]>([])
        let store = store(mode: .add(kidA), saved: saved, school: SchoolCalendar(terms: [term]))
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.runsStartText, "9 Nov")
        XCTAssertEqual(store.state.runsEndText, "End of term")
        XCTAssertEqual(store.state.termCaption, "This term ends 20 Nov")
        XCTAssertEqual(store.state.runsEndTabs.map(\.1), ["End of term", "Date", "Times", "No end"])

        await store.send(.runsEndTapped)
        await store.send(.runsEndKindPicked(.date))
        XCTAssertEqual(store.state.runsEndText, "20 Nov", "a date starts at the term's end")
        await store.send(.cardClosed)
        XCTAssertEqual(store.state.runsEndText, "End of term")

        await store.send(.runsEndTapped)
        await store.send(.runsEndKindPicked(.count))
        await store.send(.runsTimesStepped(-2))
        await store.send(.runsEndDoneTapped)
        XCTAssertEqual(store.state.runsEndText, "After 8 times")
        await fill(store)
        await store.send(.saveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(saved.value.first?.runsEnd, .count(8))
    }

    func testNoSchoolCalendarOffersNoEndOfTerm() async {
        let store = store(mode: .add(kidA))
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.runsEndText, "No end")
        XCTAssertEqual(store.state.runsEndTabs.map(\.0), [.date, .count, .none])
    }

    // MARK: Linked time and No school days

    func testAfterSchoolWithAGapAndNoSchoolDays() async {
        let saved = LockIsolated<[ScheduleItem]>([])
        let store = store(mode: .add(kidA), saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await fill(store)
        XCTAssertFalse(store.state.showsNoSchool)
        await store.send(.fromRowTapped)
        await store.send(.fromPicked("school"))
        XCTAssertEqual(store.state.card, .from, "the card stays open for the minutes after")
        await store.send(.fromGapStepped(1))
        await store.send(.fromGapStepped(1))
        await store.send(.fromGapStepped(1))
        await store.send(.cardClosed)
        XCTAssertEqual(store.state.fromText, "After School · 15 min after")
        XCTAssertTrue(store.state.showsNoSchool)
        XCTAssertFalse(store.state.showsSkipHolidays)
        XCTAssertEqual(store.state.noSchoolText, "Skip")

        await store.send(.noSchoolRowTapped)
        await store.send(.noSchoolSetTime(true))
        await store.send(.noSchoolStartPicked(F.monday.date(minute: 600, calendar: F.calendar)))
        await store.send(.noSchoolGoingTapped(.walk))
        await store.send(.noSchoolDoneTapped)
        XCTAssertEqual(store.state.noSchoolText, "At 10:00 am")
        await store.send(.saveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(saved.value.first?.afterGap, 15)
        XCTAssertEqual(saved.value.first?.noSchool?.start, 600)
        XCTAssertEqual(saved.value.first?.noSchool?.trip?.way, .walk)
    }
}
