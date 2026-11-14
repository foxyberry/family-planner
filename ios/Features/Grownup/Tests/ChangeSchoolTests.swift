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
                       savedRoutines: LockIsolated<[Routine]>) -> TestStoreOf<ChangeSchoolFeature> {
        let directory = [riverside]
        let store = TestStore(initialState: ChangeSchoolFeature.State(kid: SeedData.kidA.id, today: tuesday,
                                                                      calendar: F.calendar)) {
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
        XCTAssertEqual(store.state.startsOn, .date, "no term dates: pick a date")
        await store.send(.textChanged("river"))
        XCTAssertEqual(store.state.matches.map(\.id), ["riverside-primary"])
        await store.send(.picked(riverside))
        let january = Day(year: 2027, month: 1, day: 4)
        await store.send(.datePicked(january.date(calendar: F.calendar)))
        await store.send(.saveTapped)
        await store.receive(\.saved)
        await store.receive(\.delegate.openBuses)
        XCTAssertEqual(kids.value.last?.school?.name, SeedData.kidA.school?.name, "the old school until the day")
        XCTAssertEqual(kids.value.last?.pendingSchool?.school.name, "Riverside Primary")
        XCTAssertEqual(kids.value.last?.pendingSchool?.from, january)
        // From that day the weekday template uses the new hours (Arrive by 7:45, ends 1:30).
        let school = routines.value.last?.blocks.first { $0.kind == .school }
        XCTAssertEqual(routines.value.last?.from, january)
        XCTAssertEqual(school?.start, 465)
        XCTAssertEqual(school?.end, 810)
    }

    func testCancelTheChangeKeepsTheOldSchool() async {
        var kidA = SeedData.kidA
        kidA.pendingSchool = PendingSchool(school: School(entry: riverside), from: Day(year: 2027, month: 1, day: 4))
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(kids: [kidA, SeedData.kidB], savedKids: kids, savedRoutines: routines)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.pendingLine, "From 4 Jan: Riverside Primary")
        await store.send(.cancelChangeTapped)
        XCTAssertTrue(store.state.isConfirmingCancel)
        await store.send(.cancelConfirmed)
        await store.finish()
        XCTAssertNil(kids.value.last?.pendingSchool)
        XCTAssertEqual(kids.value.last?.school, SeedData.kidA.school)
    }

    func testAPendingSchoolBecomesTheSchoolOnItsDay() {
        var kidA = SeedData.kidA
        let day = Day(year: 2027, month: 1, day: 4)
        kidA.pendingSchool = PendingSchool(school: School(entry: riverside), from: day)
        XCTAssertEqual(kidA.applyingPendingSchool(on: Day(year: 2027, month: 1, day: 3)), kidA)
        let after = kidA.applyingPendingSchool(on: day)
        XCTAssertEqual(after.school?.name, "Riverside Primary")
        XCTAssertNil(after.pendingSchool)
    }
}
