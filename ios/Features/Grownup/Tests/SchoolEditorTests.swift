import ComposableArchitecture
import Domain
import Foundation
import Grownup
import ScheduleStore
import XCTest

/// G4 · Edit School (first part), with the seed family (made-up school and times).
@MainActor
final class SchoolEditorTests: XCTestCase {
    private typealias F = Fixture
    private let tuesday = Day(year: 2026, month: 11, day: 10)

    private func store(savedKids: LockIsolated<[Kid]>, savedRoutines: LockIsolated<[Routine]>,
                       directoryID: String? = nil, schools: [SchoolEntry] = [])
        -> TestStoreOf<SchoolEditorFeature> {
        var kidA = SeedData.kidA
        kidA.school?.arriveBy = 450
        kidA.school?.latest = 460
        kidA.school?.directoryID = directoryID
        let kids = [kidA, SeedData.kidB]
        let store = TestStore(initialState: SchoolEditorFeature.State(kid: kidA.id, today: tuesday, calendar: F.calendar)) {
            SchoolEditorFeature()
        } withDependencies: {
            $0.calendar = F.calendar
            $0.scheduleStore.load = { ScheduleSnapshot(kids: kids, routines: SeedData.routines, items: []) }
            $0.scheduleStore.saveKid = { kid in savedKids.withValue { $0.append(kid) } }
            $0.scheduleStore.saveRoutine = { routine in savedRoutines.withValue { $0.append(routine) } }
            $0.schoolDirectory.calendar = { _, _ in .none }
            $0.schoolDirectory.schools = { schools }
            $0.uuid = .incrementing
        }
        store.exhaustivity = .off
        return store
    }

    /// Spec G4 Terms (layout v63): a school the list knows shows its terms as text, with no MOE
    /// switch; a school typed by hand, or one whose terms the list doesn't know, keeps the switch.
    func testTheMoeSwitchShowsOnlyForASchoolTheListDoesNotKnow() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        func entry(_ follows: Bool?) -> SchoolEntry {
            SchoolEntry(id: "example-primary", name: "Example Primary School", kind: .moe(.primary), area: "Example Town",
                        hasPrimary: true, followsMoeTerms: follows, hours: nil, breakCount: 0, searchKeys: [])
        }
        for (directoryID, schools, shows) in [(String?.none, [SchoolEntry](), true),
                                              ("example-primary", [entry(true)], false),
                                              ("example-primary", [entry(false)], false),
                                              ("example-primary", [entry(nil)], true)] {
            let store = store(savedKids: kids, savedRoutines: routines, directoryID: directoryID, schools: schools)
            await store.send(.task)
            await store.receive(\.loaded)
            await store.receive(\.schoolYearLoaded)
            XCTAssertEqual(store.state.showsMoeCheck, shows, "\(String(describing: directoryID)) \(schools.map(\.followsMoeTerms))")
        }
    }

    func testMovingTheStartMovesArriveByAndKeepsTheGrace() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines)
        await store.send(.task)
        await store.receive(\.loaded)
        XCTAssertEqual(store.state.everyTitle, "Every school day")
        XCTAssertFalse(store.state.canSave, "nothing changed yet")
        await store.send(.startPicked(tuesday.date(minute: 480, calendar: F.calendar)))
        XCTAssertEqual(store.state.school?.start, 480)
        XCTAssertEqual(store.state.arriveBy, 480)
        XCTAssertEqual(store.state.latest, 490)
        await store.send(.endPicked(tuesday.date(minute: 870, calendar: F.calendar)))
        await store.send(.saveTapped)
        await store.receive(\.saved)
        await store.receive(\.delegate.finished)
        XCTAssertEqual(kids.value.last?.school?.start, 480)
        XCTAssertEqual(kids.value.last?.school?.end, 870)
        // The weekday template from today: School's slice on the new times, its neighbours following.
        let school = routines.value.last?.blocks.first { $0.kind == .school }
        XCTAssertEqual(routines.value.last?.from, tuesday)
        XCTAssertEqual(school?.start, 480)
        XCTAssertEqual(school?.end, 870)
    }

    func testDaysArriveByMedalAndGoing() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.dayToggled(.friday))
        XCTAssertEqual(store.state.everyTitle, "Mon · Tue · Wed · Thu")
        await store.send(.arriveByPicked(tuesday.date(minute: 440, calendar: F.calendar)))
        XCTAssertEqual(store.state.latest, 450, "Latest keeps the 10-minute grace")
        await store.send(.medalToggled)
        XCTAssertFalse(store.state.medal)
        await store.send(.goingTapped)
        await store.receive(\.delegate.openBuses)
    }

    /// Board G4 Bring (F2): up to four things, named as the thing; Cancel puts them back.
    func testBringPicksAndCancels() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.bringRowTapped)
        await store.send(.bringToggled(.libraryBag))
        await store.send(.bringToggled(.waterBottle))
        XCTAssertEqual(store.state.bringText, "Library bag · Water bottle")
        await store.send(.bringDoneTapped)
        await store.send(.bringRowTapped)
        await store.send(.bringToggled(.waterBottle))
        await store.send(.bringClosed)
        XCTAssertEqual(store.state.bringText, "Library bag · Water bottle", "Cancel puts the list back")
        await store.send(.saveTapped)
        await store.receive(\.saved)
        XCTAssertEqual(kids.value.last?.school?.bring?.map(\.picture), ["libraryBag", "waterBottle"])
    }

    /// Spec "Edit scope": This day keeps the school record and saves only the day's own template.
    func testThisDayMovesOnlyThatDay() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.scopeTapped(.thisDay))
        await store.send(.endPicked(tuesday.date(minute: 780, calendar: F.calendar)))
        await store.send(.saveTapped)
        await store.receive(\.saved)
        XCTAssertTrue(kids.value.isEmpty, "the school record stays")
        XCTAssertEqual(routines.value.last?.onlyOn, tuesday)
        XCTAssertEqual(routines.value.last?.blocks.first { $0.kind == .school }?.end, 780)
    }

    /// Spec "E5 School rule": This day shows "{Day d Mon} only" and skips School on that day (a sick
    /// day), saved at once; "Bring back" undoes it.
    func testThisDaySkipsSchoolAndBringsItBack() async {
        let kids = LockIsolated<[Kid]>([]), routines = LockIsolated<[Routine]>([])
        let store = store(savedKids: kids, savedRoutines: routines)
        await store.send(.task)
        await store.receive(\.loaded)
        await store.send(.scopeTapped(.thisDay))
        XCTAssertEqual(store.state.thisDayTitle, "Tue 10 Nov only")
        XCTAssertEqual(store.state.skipTitle, "Skip this day")
        await store.send(.skipDayTapped)
        await store.receive(\.daySkipSaved)
        XCTAssertEqual(routines.value.last?.onlyOn, tuesday)
        XCTAssertEqual(routines.value.last?.blocks.first { $0.kind == .school }?.isSkipped, true)
        XCTAssertTrue(store.state.isDaySkipped)
        await store.send(.skipDayTapped)
        await store.receive(\.daySkipSaved)
        XCTAssertEqual(routines.value.last?.blocks.first { $0.kind == .school }?.isSkipped, false)
        XCTAssertTrue(kids.value.isEmpty, "the school record stays")
    }
}
