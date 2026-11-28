import ComposableArchitecture
import DesignSystem
import Domain
import Foundation
import Grownup
import HolidayProvider
import KitArt
import Localization
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

    /// Spec C3 "What" (N15): "More" offers the country flags after the pictures, in kit order, and a
    /// picked flag becomes the item's picture, in the row's last slot (next to "More").
    func testMoreOffersTheCountryFlags() async {
        XCTAssertEqual(ItemEditorFeature.State.flags, KitSlot.allCases.filter { $0.rawValue.hasPrefix("flag") })
        XCTAssertTrue(Set(ItemEditorFeature.State.flags).isDisjoint(with: ItemEditorFeature.State.pictures))
        let store = store(mode: .add(kidA), saved: LockIsolated([]))
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.morePicturesTapped)
        await store.send(.picturePicked("flagJP"))
        XCTAssertEqual(store.state.form.iconName, "flagJP")
        XCTAssertEqual(store.state.form.name, "Japanese", "a flag is named by its language (spec seed data)")
        XCTAssertFalse(store.state.isPickingMorePictures)
        XCTAssertEqual(store.state.whatRow.last, "flagJP")
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

    /// Design answer (2026-11-28): only adding asks who it is for; an edit shows its kids' faces
    /// after the title instead.
    func testEditsShowTheirKidsInTheHeaderNotAForRow() async {
        let adding = store(mode: .add(kidA))
        await adding.send(.task)
        await adding.receive(\.loaded)
        XCTAssertTrue(adding.state.showsForRow)
        XCTAssertEqual(adding.state.headerFaces, [])

        let swim = F.weekly()
        let editing = store(mode: .editWeekly(swim), items: [swim])
        await editing.send(.task)
        await editing.receive(\.loaded)
        XCTAssertFalse(editing.state.showsForRow)
        XCTAssertEqual(editing.state.headerFaces, [.init(face: "kidGirl", colorIndex: 0)])

        let party = F.once("Party", on: Day(year: 2026, month: 11, day: 14))
        let both = store(mode: .editOnce(party), items: [party])
        await both.send(.task)
        await both.receive(\.loaded)
        XCTAssertFalse(both.state.showsForRow)
        XCTAssertEqual(both.state.headerFaces, [.init(face: "kidGirl", colorIndex: 0), .init(face: "kidBoy", colorIndex: 1)])
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

    /// Spec "Add-screen feedback": Save stays on; only a save on its way blocks it.
    func testCanSaveUnlessSaving() async {
        let store = store(mode: .add(kidA))
        XCTAssertTrue(store.state.canSave, "on even without a name: it explains instead")
        await fill(store)
        await store.send(.saveTapped)
        XCTAssertFalse(store.state.canSave, "already saving")
    }

    func testConfirmLabels() async {
        let party = F.once("Party", on: Day(year: 2026, month: 11, day: 14))
        let store = store(mode: .editOnce(party), items: [party])
        await store.send(.binding(.set(\.form.name, "Big party")))
        await store.send(.backTapped)
        XCTAssertEqual([store.state.confirmCancelTitle, store.state.confirmAcceptTitle], ["Keep editing", "Leave"])
        // Board C3x: "Leave" is the main, lateText choice, and the card points at "←".
        XCTAssertTrue(store.state.confirmIsDestructive)
        XCTAssertTrue(store.state.confirmPointsAtBack)
        await store.send(.confirmCancelled)
        await store.send(.removeTapped)
        XCTAssertEqual([store.state.confirmCancelTitle, store.state.confirmAcceptTitle], ["Keep", "Remove"])
        XCTAssertTrue(store.state.confirmIsDestructive)
    }

    /// Spec "Add-screen feedback": Save with a problem shows it under its field and scrolls there;
    /// nothing is saved, and fixing it moves the caption to the next problem.
    func testSaveWithAProblemShowsItUnderItsFieldAndScrollsThere() async {
        let saved = LockIsolated<[ScheduleItem]>([])
        let store = store(mode: .add(kidA), saved: saved)
        XCTAssertNil(store.state.problem(for: .name), "board C3: no warning before Save")
        await store.send(.binding(.set(\.form.name, " ")))
        XCTAssertNil(store.state.problem(for: .name), "still none before Save")
        await store.send(.saveTapped)
        XCTAssertEqual(store.state.problem(for: .name), .noName)
        XCTAssertNil(store.state.problem(for: .when))
        XCTAssertEqual(store.state.scrollTarget?.id, "name")
        XCTAssertEqual(saved.value, [])
        await fill(store)
        await store.send(.binding(.set(\.form.end, 900)))
        XCTAssertNil(store.state.problem(for: .name))
        XCTAssertEqual(store.state.problem(for: .when), .endsBeforeStart)
        await store.send(.saveTapped)
        XCTAssertEqual(store.state.scrollTarget, GrownupScrollTarget(id: "when", request: 2))
    }

    func testDateChipsNameTheWeekdayAndPageEarlierOnlyAfterPagingOn() async {
        let store = store(mode: .add(kidA), repeats: .once)
        XCTAssertEqual(store.state.dateChips.map(\.weekday), ["Mon", "Tue", "Wed", "Thu", "Fri"])
        XCTAssertEqual(store.state.dateChips.map(\.day), store.state.visibleDates)
        XCTAssertEqual(store.state.dateChips.map(\.isOn), [true, false, false, false, false])
        XCTAssertFalse(store.state.canPageEarlier, "‹ is off on the first page")
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
        // Spec "Add-screen feedback": the new item shows as soon as it has a time, "New" until named.
        XCTAssertEqual(store.state.preview?.rows.filter(\.isNew).map(\.title), ["New"])
        XCTAssertEqual(store.state.preview?.rows.filter(\.isNew).first?.isUnnamed, true)
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

    /// "More" opens every picture; picking one closes it and puts it in the row's last slot, the
    /// others staying where they were (design answer 2026-11-28).
    func testMorePicturesPickTakesTheLastSlot() async {
        let store = store(mode: .add(.kid(SeedData.kidA.id)))
        store.exhaustivity = .off
        await store.send(.morePicturesTapped) { $0.isPickingMorePictures = true }
        let before = store.state.whatRow
        await store.send(.picturePicked("cake")) { $0.isPickingMorePictures = false }
        XCTAssertEqual(store.state.whatRow, Array(before.dropLast()) + ["cake"])
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
        XCTAssertEqual(store.state.card?.kind, .from)
        XCTAssertEqual(store.state.fromCircles.map(\.caption), ["Home", "School"])
        await store.send(.fromPicked("school"))
        XCTAssertEqual(store.state.card?.kind, .from, "open until Done (board F1)")
        await store.send(.cardDoneTapped)
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
        await store.send(.beforeRowTapped)
        await store.send(.bringToggled(.backpack))
        await store.send(.bringToggled(.waterBottle))
        await store.send(.cardDoneTapped)
        XCTAssertEqual(store.state.form.bringText, "Backpack · Water bottle")
        await store.send(.beforeRowTapped)
        await store.send(.bringCircleTapped("more"))
        XCTAssertGreaterThan(store.state.bringSlots.count, 3)
        XCTAssertFalse(store.state.bringSlots.contains(.debugLadybug), "object pictures only")
        XCTAssertFalse(store.state.bringSlots.contains { $0.rawValue.contains("Pax") || $0.rawValue.hasPrefix("sky") })
        await store.send(.bringToggled(.lunchBox))
        await store.send(.cardClosed)
        XCTAssertEqual(store.state.form.bring.map(\.picture), ["backpack", "waterBottle"])
    }

    func testMedalSwitchNeedsATrip() async {
        let store = store(mode: .add(kidA))
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertFalse(store.state.form.canSwitchMedal, "off without a trip")
        await store.send(.medalToggled)
        XCTAssertFalse(store.state.form.medalIsOn)
        await store.send(.goingTapped(.car))
        XCTAssertTrue(store.state.form.canSwitchMedal)
        XCTAssertEqual([store.state.form.leaveText, store.state.form.leaveCaption].map { $0 != nil }, [true, true],
                       "a trip's Leave row has its minutes and caption")
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
        XCTAssertEqual(store.state.termCaption, "Fri 20 Nov")
        XCTAssertEqual(store.state.runsEndTabs.map(\.1), ["End of this term", "On a date", "After … times", "No end"])

        await store.send(.runsEndTapped)
        await store.send(.runsEndKindPicked(.date))
        XCTAssertEqual(store.state.runsEndText, "20 Nov", "a date starts at the term's end")
        await store.send(.cardClosed)
        XCTAssertEqual(store.state.runsEndText, "End of term")

        await store.send(.runsEndTapped)
        await store.send(.runsEndKindPicked(.count))
        await store.send(.runsTimesStepped(-2))
        XCTAssertEqual(store.state.runsCountText, "8 times")
        await store.send(.cardDoneTapped)
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
        XCTAssertEqual(store.state.card?.kind, .from, "the card stays open for the minutes after")
        await store.send(.fromGapStepped(1))
        await store.send(.fromGapStepped(1))
        await store.send(.fromGapStepped(1))
        await store.send(.cardDoneTapped)
        XCTAssertEqual(store.state.fromText, "After School · 15 min after")
        XCTAssertTrue(store.state.showsNoSchool)
        XCTAssertFalse(store.state.showsSkipHolidays)
        XCTAssertEqual(store.state.noSchoolText, "Skip")

        await store.send(.noSchoolRowTapped)
        await store.send(.noSchoolSetTime(true))
        XCTAssertEqual(store.state.form.noSchoolWay, .walk, "a set time needs a trip; Walk first")
        XCTAssertEqual(store.state.noSchoolGoing.map(\.caption), ["Walk", "Bus", "Car"])
        await store.send(.noSchoolStartPicked(F.monday.date(minute: 600, calendar: F.calendar)))
        XCTAssertEqual(store.state.noSchoolEndLabel, "11:00 am", "the item's length after the start")
        await store.send(.noSchoolEndPicked(F.monday.date(minute: 690, calendar: F.calendar)))
        await store.send(.noSchoolGoingTapped(.bus))
        await store.send(.noSchoolGoingTapped(.walk))
        await store.send(.cardDoneTapped)
        XCTAssertEqual(store.state.noSchoolText, "At 10:00 am")
        await store.send(.saveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(saved.value.first?.afterGap, 15)
        XCTAssertEqual(saved.value.first?.noSchool?.start, 600)
        XCTAssertEqual(saved.value.first?.noSchool?.trip?.way, .walk)
        XCTAssertEqual(saved.value.first?.noSchool?.end, 690)
    }

    // MARK: Form cards (boards F1–F4)

    func testCancelOnAFormCardPutsTheFormBack() async {
        let store = store(mode: .add(kidA))
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.fromRowTapped)
        await store.send(.fromPicked("school"))
        await store.send(.fromGapStepped(1))
        await store.send(.cardClosed)
        XCTAssertNil(store.state.card)
        XCTAssertNil(store.state.form.after, "Cancel keeps Home")
        XCTAssertEqual(store.state.form.afterGap, 0)
    }

    func testBringRowShowsFourThingsAndMore() async {
        let store = store(mode: .add(kidA))
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.beforeRowTapped)
        XCTAssertEqual(store.state.bringRow.map(\.caption), ["Backpack", "Lunch box", "Water bottle", "Shoes", ""])
        XCTAssertEqual(store.state.bringRow.last?.word, "More")
        await store.send(.bringCircleTapped("backpack"))
        await store.send(.bringCircleTapped("more"))
        XCTAssertTrue(store.state.isPickingMoreBring)
        await store.send(.bringToggled(.teddy))
        XCTAssertEqual(store.state.bringRow.map(\.id), ["backpack", "lunchBox", "waterBottle", "teddy", "more"],
                       "a thing from More takes the place of an unpicked one")
        await store.send(.cardDoneTapped)
        XCTAssertEqual(store.state.form.bringText, "Backpack · Teddy")
    }

    /// Board G2m: an every-month series edits with its rule in the Days row, "Every 2nd Sat" and
    /// "Remove every month"; the rule follows Runs' start.
    func testEditingAnEveryMonthItem() async {
        let library = ScheduleItem(id: UUID(), title: "Library visit", iconName: "actStory", audience: kidA,
                                   start: 600, end: 660,
                                   recurrence: .monthly(.nthWeekday(2, .saturday), from: Day(year: 2026, month: 11, day: 14),
                                                        until: nil),
                                   skippedDays: [], skipsHolidays: false, showsStar: false)
        let store = store(mode: .editWeekly(library), items: [library])
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.everyTitle, "Every 2nd Sat")
        XCTAssertEqual(store.state.removeSeriesTitle, "Remove every month")
        XCTAssertEqual(store.state.monthlyChoices.map(\.title), ["2nd Sat", "Day 14"])
        await store.send(.monthlyRuleTapped(byDate: true))
        XCTAssertEqual(store.state.everyTitle, "Every 14th")
        await store.send(.runsStartPicked(Day(year: 2026, month: 12, day: 12).date(calendar: F.calendar)))
        XCTAssertEqual(store.state.form.monthlyRule, .dayOfMonth(12))
    }

    /// Views hold no values: the rows' labels, the tabs, the checks and every card's words come
    /// from State, through the injected localizer.
    func testTheWordsComeFromState() {
        let now = F.monday.date(minute: 600, calendar: F.calendar)
        let state = ItemEditorFeature.State(mode: .add(kidA), repeats: .weekly, now: now, calendar: F.calendar)
        XCTAssertEqual(state.repeatTabs.map(\.0), [.once, .weekly, .monthly])
        XCTAssertEqual(state.scopeTabs.map(\.0), [.thisDay, .allDays])
        XCTAssertEqual(state.fromWhenChoice, .today, "the card shows Today until it opens")
        func words(_ state: ItemEditorFeature.State) -> [String] {
            [state.forLabel, state.whatLabel, state.nameLabel, state.whenLabel, state.repeatLabel, state.daysLabel,
             state.runsLabel, state.fromLabel, state.noSchoolLabel, state.goingLabel, state.leaveLabel,
             state.beforeLabel, state.backLabel, state.bundlesCaption, state.bringCaption, state.takesLabel,
             state.medalLabel, state.moreTitle, state.skipHolidaysTitle, state.starTitle,
             state.nothingText, state.cardDoneTitle, state.cardCancelTitle, state.runsCardTitle, state.runsCountText,
             state.startsLabel, state.noSchoolCardTitle, state.noSchoolSkipTitle, state.noSchoolAtTitle,
             state.usesBusesTitle, state.fromWhenTitle, state.fromWhenSave, state.fromWhenCancel]
                + state.repeatTabs.map(\.1) + state.scopeTabs.map(\.1)
        }
        XCTAssertEqual(words(state),
                       ["For", "What", "Name", "When", "Repeat", "Days", "Runs", "From", "Off days", "Going", "Leave",
                        "Before", "Back", "Bundles", "Bring", "Takes", "Medal", "More", "Skip school holidays", "A star on the clock that day", "Nothing",
                        "Done", "Cancel", "Ends", "\(state.form.times) times", "Starts", "Off days", "Skip",
                        "At a set time", "Uses Our buses %@", "Change from when?", "Save", "Cancel", "Once", "Weekly",
                        "Monthly", "This day", "All days"])
        let keys = withDependencies { $0.localizer = .keys } operation: {
            ItemEditorFeature.State(mode: .add(kidA), repeats: .weekly, now: now, calendar: F.calendar)
        }
        XCTAssertEqual(words(keys),
                       ["editor.row.for", "editor.row.what", "editor.row.name", "editor.row.when", "editor.row.repeat",
                        "editor.row.days", "editor.row.runs", "editor.row.from", "editor.row.no_school", "going.label",
                        "going.leave", "editor.row.before", "editor.row.back", "before.bundles", "before.bring", "back.takes",
                        "editor.row.medal", "picker.more", "editor.skip_holidays",
                        "editor.star", "editor.row.nothing", "c5.done", "card.cancel", "runs.card.title",
                        "runs.count.value|\(keys.form.times)", "from.starts", "no_school.card.title",
                        "no_school.pick.skip", "no_school.pick.at", "going.uses_buses|%@", "from_when.title",
                        "from_when.save", "from_when.cancel", "editor.repeat.once", "editor.repeat.weekly",
                        "editor.repeat.monthly", "editor.scope.this_day", "editor.scope.all_days"])
    }

    /// Issue 024 (boards F2, F7): the Before card picks the kid's bundles; the Back card picks the way home
    /// and its minutes; the rows say what was picked; a tap outside puts the form back.
    func testBeforeAndBackCards() async {
        let store = store(mode: .add(kidA))
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.goingTapped(.car))
        XCTAssertTrue(store.state.showsBefore, "an outing")
        XCTAssertTrue(store.state.showsBack, "a new item ends its chain")
        await store.send(.beforeRowTapped)
        XCTAssertTrue(store.state.beforeKidTabs.isEmpty, "one kid: no tabs")
        let morning = MissionBundle.morningID(for: SeedData.kidA.id)
        XCTAssertEqual(store.state.bundleChips.map(\.id), [morning])
        await store.send(.bundleToggled(morning))
        await store.send(.bringToggled(.swimsuit))
        await store.send(.cardDoneTapped)
        XCTAssertEqual(store.state.form.lists.before, [morning])
        XCTAssertEqual(store.state.beforeText, "Morning routine · Swimsuit")
        await store.send(.backRowTapped)
        XCTAssertNil(store.state.backText, "None")
        XCTAssertFalse(store.state.showsTakes)
        await store.send(.wayHomePicked("pickup"))
        await store.send(.homeAfterStepped(1))
        await store.send(.homeAfterStepped(1))
        await store.send(.cardDoneTapped)
        XCTAssertEqual(store.state.backText, "Pickup · 10 min")
        await store.send(.backRowTapped)
        await store.send(.wayHomePicked("walk"))
        await store.send(.cardClosed)
        XCTAssertEqual(store.state.form.lists.wayHome, .pickup, "a tap outside puts it back")
    }

    /// #289 review: an item at home (no trip, not after an event) has no Before or Back, and saves no lists.
    func testAnItemAtHomeHasNoListsToSave() async {
        let saved = LockIsolated<[ScheduleItem]>([])
        let store = store(mode: .add(kidA), saved: saved)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.goingTapped(.car))
        await store.send(.backRowTapped)
        await store.send(.wayHomePicked("pickup"))
        await store.send(.cardDoneTapped)
        await store.send(.goingTapped(nil))
        XCTAssertFalse(store.state.showsBefore)
        XCTAssertFalse(store.state.showsBack)
        XCTAssertEqual(store.state.form.item(id: UUID(), today: F.monday).lists, EventLists())
    }

    /// #289 review: This day has no Before or Back; a change made on All days goes back when This day is
    /// picked, so a This-day save drops nothing silently.
    func testThisDayPutsTheListsBack() async {
        let swim = SeedData.items(today: F.monday, calendar: F.calendar)[0]
        let store = store(mode: .editWeekly(swim), items: [swim])
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.scopeTapped(.allDays))
        await store.send(.backRowTapped)
        await store.send(.wayHomePicked("pickup"))
        await store.send(.cardDoneTapped)
        XCTAssertEqual(store.state.form.lists.wayHome, .pickup)
        await store.send(.scopeTapped(.thisDay))
        XCTAssertEqual(store.state.form.lists, swim.lists)
    }
}
