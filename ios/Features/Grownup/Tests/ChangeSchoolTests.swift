import ComposableArchitecture
import Domain
import Foundation
import Grownup
import ScheduleStore
import SchoolDirectory
import XCTest

/// G7 · Change school with made-up schools: search, pick, "Starts on", Save, pending, cancel.
@MainActor
final class ChangeSchoolTests: XCTestCase {
    private typealias F = Fixture
    private let tuesday = Day(year: 2026, month: 11, day: 10)
    private let riverside = SchoolEntry(id: "riverside-primary", name: "Riverside Primary", kind: .moe(.primary),
                                        area: "Example Town", hasPrimary: true, followsMoeTerms: true,
                                        hours: SchoolHours(start: 465, end: 810, checked: Day(year: 2026, month: 1, day: 5)),
                                        breakCount: 0, searchKeys: [])

    private func store(kids: [Kid] = SeedData.kids, savedKids: LockIsolated<[Kid]>,
                       savedRoutines: LockIsolated<[Routine]>,
                       opensAt: ChangeSchoolFeature.Place? = nil) -> TestStoreOf<ChangeSchoolFeature> {
        let directory = [riverside]
        let store = TestStore(initialState: ChangeSchoolFeature.State(kid: SeedData.kidA.id, today: tuesday,
                                                                      calendar: F.calendar, opensAt: opensAt)) {
            ChangeSchoolFeature()
        } withDependencies: {
            $0.calendar = F.calendar
            $0.scheduleStore.load = { ScheduleSnapshot(kids: kids, routines: SeedData.routines, items: []) }
            $0.scheduleStore.saveKid = { kid in savedKids.withValue { $0.append(kid) } }
            $0.scheduleStore.saveRoutine = { routine in savedRoutines.withValue { $0.append(routine) } }
            $0.schoolDirectory.schools = { directory }
            $0.schoolDirectory.calendar = { _, _ in .none }
        }
        store.exhaustivity = .off
        return store
    }

    func testPickAndStartOnADateMakesAPendingChange() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.form.startsOn, .date, "no term dates: pick a date")
        await store.send(.textChanged("river"))
        XCTAssertEqual(store.state.form.matches.map(\.id), ["riverside-primary"])
        await store.send(.picked(riverside))
        let january = Day(year: 2027, month: 1, day: 4)
        await store.send(.datePicked(january.date(calendar: F.calendar)))
        await store.send(.saveTapped)
        await store.receive(\.saved)
        await store.receive(\.delegate.openBuses)
        XCTAssertEqual(kids.value.last?.school?.name, SeedData.kidA.school?.name, "the old school until the day")
        XCTAssertEqual(kids.value.last?.pendingSchool?.school?.name, "Riverside Primary")
        XCTAssertEqual(kids.value.last?.pendingSchool?.from, january)
        // From that day the weekday template uses the new hours (Arrive by 7:45, ends 1:30).
        let school = routines.value.last?.blocks.first { $0.kind == .school }
        XCTAssertEqual(routines.value.last?.from, january)
        XCTAssertEqual(school?.start, 465)
        XCTAssertEqual(school?.end, 810)
    }

    /// A waiting hours change of the old school: a move after its day keeps it (it comes first); a move
    /// on or before its day cuts it off. It wrote no template, so the move writes only its own.
    func testAMoveBeforeAWaitingHoursChangeDropsIt() async {
        let waitingDay = Day(year: 2026, month: 11, day: 18)
        var later = SeedData.kidA.school!
        later.end = 840
        let kidA = SeedData.kidA.savingSchool(later, from: waitingDay, today: tuesday)
        func move(on day: Day) async -> (kid: Kid?, routines: [Routine]) {
            let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
            let store = store(kids: [kidA, SeedData.kidB], savedKids: kids, savedRoutines: routines)
            await store.send(.task)
            await store.receive(\.loaded)
            await store.send(.picked(riverside))
            await store.send(.datePicked(day.date(calendar: F.calendar)))
            await store.send(.saveTapped)
            await store.receive(\.saved)
            return (kids.value.last, routines.value)
        }
        let after = await move(on: Day(year: 2027, month: 1, day: 4))
        XCTAssertEqual(after.kid?.pendingHours?.from, waitingDay)
        let before = await move(on: Day(year: 2026, month: 11, day: 16))
        XCTAssertNil(before.kid?.pendingHours)
        XCTAssertEqual(before.routines.map(\.from), [Day(year: 2026, month: 11, day: 16)], "only the move's version")
        let sameDay = await move(on: waitingDay)
        XCTAssertNil(sameDay.kid?.pendingHours, "on its day the move wins")
    }

    /// Board G7: picking a school opens the "Starts on" card; its Cancel goes back to the search.
    func testPickingOpensTheCardAndCancelClosesIt() async {
        let store = store(savedKids: .init([]), savedRoutines: .init([]))
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertFalse(store.state.form.isShowingStartsOn)
        await store.send(.picked(riverside))
        XCTAssertTrue(store.state.form.isShowingStartsOn)
        XCTAssertEqual(store.state.form.startsOnTabs.map(\.1), ["Next term", "Date"])
        await store.send(.cardCancelled)
        XCTAssertFalse(store.state.form.isShowingStartsOn)
        XCTAssertEqual(store.state.form.text, "")
    }

    func testCancelTheChangeKeepsTheOldSchool() async {
        var kidA = SeedData.kidA
        kidA.pendingSchool = PendingSchool(school: School(entry: riverside), from: Day(year: 2027, month: 1, day: 4))
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(kids: [kidA, SeedData.kidB], savedKids: kids, savedRoutines: routines)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.form.pendingLine, "From 4 Jan: Riverside Primary")
        await store.send(.cancelChangeTapped)
        XCTAssertTrue(store.state.form.isConfirmingCancel)
        await store.send(.cancelConfirmed)
        await store.finish()
        XCTAssertNil(kids.value.last?.pendingSchool)
        XCTAssertEqual(kids.value.last?.school, SeedData.kidA.school)
    }

    /// Views hold no values: before the store answers there is no form (no "At home" beside a
    /// picked School tab); `.loaded` builds the whole form, on the kid's place.
    func testLoadingShowsNoFormAndLoadedBuildsTheWholeForm() async {
        let store = store(savedKids: .init([]), savedRoutines: .init([]))
        XCTAssertEqual(store.state.phase, .loading)
        XCTAssertFalse(store.state.hidesKeyboard)
        await store.send(.task)
        await store.receive(\.loaded)
        let form = store.state.form
        XCTAssertEqual(form.stored, SeedData.kidA)
        XCTAssertEqual(form.routines, SeedData.routines)
        XCTAssertEqual(form.directory.map(\.id), ["riverside-primary"])
        XCTAssertEqual(form.place, .school, "Kid A goes to school")
        XCTAssertEqual(form.currentName, SeedData.kidA.school?.name)
        XCTAssertEqual(form.startsOn, .date, "no term dates: Date")
        XCTAssertEqual(form.date, tuesday)
        XCTAssertNil(form.picked)
        XCTAssertFalse(form.isShowingStartsOn)
    }

    /// A kid the store no longer has: the screen says it could not load, with no form.
    func testAMissingKidFailsToLoad() async {
        let store = store(kids: [SeedData.kidB], savedKids: .init([]), savedRoutines: .init([]))
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.phase, .failed)
        XCTAssertEqual(store.state.loadFailedText, "Could not load. Go back and try again.")
        await store.send(.saveTapped)
        XCTAssertEqual(store.state.phase, .failed, "form actions do nothing without a form")
    }

    /// Save with no edits: Kid A stays at the same school, so nothing is saved.
    func testSaveWithNoEditsSavesNothing() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertFalse(store.state.form.canSave)
        await store.send(.saveTapped)
        await store.finish()
        XCTAssertTrue(kids.value.isEmpty)
        XCTAssertTrue(routines.value.isEmpty)
    }

    func testAPendingSchoolBecomesTheSchoolOnItsDay() {
        var kidA = SeedData.kidA
        let day = Day(year: 2027, month: 1, day: 4)
        kidA.pendingSchool = PendingSchool(school: School(entry: riverside), from: day)
        XCTAssertEqual(kidA.applyingWaitingChanges(on: Day(year: 2027, month: 1, day: 3)), kidA)
        let after = kidA.applyingWaitingChanges(on: day)
        XCTAssertEqual(after.school?.name, "Riverside Primary")
        XCTAssertNil(after.pendingSchool)
    }

    /// Design session 2026-11-15: G7 opens on the kid's place ("Goes to"); At home goes straight to
    /// the "Starts on" card, and from that day the School slice is free time and the kid has no school.
    func testAtHomeFromTodayEndsSchool() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.form.place, .school)
        XCTAssertEqual(store.state.form.placeTabs.map(\.1), ["School", "Preschool", "At home"])
        await store.send(.placeTapped(.home))
        XCTAssertTrue(store.state.form.isShowingStartsOn)
        XCTAssertEqual(store.state.form.cardTitle, "At home")
        await store.send(.datePicked(tuesday.date(calendar: F.calendar)))
        await store.send(.saveTapped)
        await store.receive(\.saved)
        await store.receive(\.delegate.finished)
        XCTAssertNil(kids.value.last?.school)
        XCTAssertNil(kids.value.last?.pendingSchool)
        XCTAssertFalse(routines.value.last?.blocks.contains { $0.kind == .school } ?? true)
    }

    /// G1's School "Remove" opens G7 on At home, with "Starts on" open, as a tap on At home does.
    func testOpensOnAtHome() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let opened = store(savedKids: kids, savedRoutines: routines, opensAt: .home)
        await opened.send(.task)
        await opened.receive(\.loaded)
        XCTAssertEqual(opened.state.form.place, .home)
        XCTAssertTrue(opened.state.form.isShowingStartsOn)
        XCTAssertEqual(opened.state.form.cardTitle, "At home")
    }

    /// A kid at home starting preschool: typed name, drop-off and pick-up, Save opens the card; a
    /// Preschool slice goes into the template on those hours.
    func testAKidAtHomeStartsPreschool() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = TestStore(initialState: ChangeSchoolFeature.State(kid: SeedData.kidB.id, today: tuesday,
                                                                      calendar: F.calendar)) {
            ChangeSchoolFeature()
        } withDependencies: {
            $0.calendar = F.calendar
            $0.scheduleStore.load = { ScheduleSnapshot(kids: SeedData.kids, routines: SeedData.routines, items: []) }
            $0.scheduleStore.saveKid = { kid in kids.withValue { $0.append(kid) } }
            $0.scheduleStore.saveRoutine = { routine in routines.withValue { $0.append(routine) } }
            $0.schoolDirectory.schools = { [] }
            $0.schoolDirectory.calendar = { _, _ in .none }
        }
        store.exhaustivity = .off
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.form.place, .home)
        XCTAssertFalse(store.state.form.canSave, "already at home")
        await store.send(.placeTapped(.preschool))
        XCTAssertFalse(store.state.form.canContinuePreschool, "no name yet")
        await store.send(.preschoolNameChanged("Example Preschool"))
        XCTAssertTrue(store.state.form.canContinuePreschool, "the default drop-off and pick-up count")
        XCTAssertEqual([store.state.form.dropOff, store.state.form.pickUp], [450, 900])
        await store.send(.dropOffPicked(Day(year: 2026, month: 1, day: 1).date(minute: 510, calendar: F.calendar)))
        await store.send(.pickUpPicked(Day(year: 2026, month: 1, day: 1).date(minute: 750, calendar: F.calendar)))
        await store.send(.preschoolSaveTapped)
        XCTAssertTrue(store.state.form.isShowingStartsOn)
        XCTAssertEqual(store.state.form.cardTitle, "Example Preschool")
        let start = Day(year: 2026, month: 12, day: 1)
        await store.send(.datePicked(start.date(calendar: F.calendar)))
        await store.send(.saveTapped)
        await store.receive(\.saved)
        await store.receive(\.delegate.openBuses)
        let pending = kids.value.last?.pendingSchool
        XCTAssertEqual(pending?.from, start)
        XCTAssertEqual(pending?.school?.kind, .preschool)
        XCTAssertEqual(pending?.school?.start, 510)
        let slice = routines.value.last?.blocks.first { $0.kind == .school }
        XCTAssertEqual(slice?.title, "Preschool")
        XCTAssertEqual(slice?.start, 510)
        XCTAssertEqual(slice?.end, 750)
    }
}

private extension ChangeSchoolFeature.State {
    /// The ready form (tests read it after `.loaded`).
    var form: ChangeSchoolFeature.Form {
        guard case let .ready(form) = phase else { preconditionFailure("the form is not loaded") }
        return form
    }
}
