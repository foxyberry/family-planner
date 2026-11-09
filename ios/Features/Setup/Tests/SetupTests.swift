import BusClient
import ComposableArchitecture
import Domain
import Grownup
import SchoolDirectory
import ScheduleStore
import Setup
import XCTest

/// First-run setup S1–S4 (spec "S1–S4") with made-up kids, schools and stops (privacy rule).
@MainActor
final class SetupTests: XCTestCase {
    /// The first card's id; `.incrementing` ids for added kids and missions start at 0.
    private let first = UUID(uuidString: "00000000-0000-4000-8000-0000000000A0")!
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Singapore")!
        return calendar
    }()
    /// Tuesday 10 Nov 2026, 10:00 in Singapore (not a holiday).
    private var now: Date { Day(year: 2026, month: 11, day: 10).date(minute: 600, calendar: calendar) }

    private let school = SchoolEntry(
        id: "example-primary", name: "Example Primary School", kind: .moe(.primary), area: "Example Town",
        hasPrimary: true, followsMoeTerms: true,
        hours: SchoolHours(start: 450, end: 810, checked: Day(year: 2026, month: 11, day: 9)),
        searchKeys: ["example primary", "eps"])
    private let international = SchoolEntry(
        id: "example-international", name: "Example International School", kind: .other(curriculum: "IB PYP"),
        area: nil, hasPrimary: true, followsMoeTerms: false, hours: nil, breakCount: 3, searchKeys: ["eis"])

    private func store(saved: LockIsolated<[ScheduleSnapshot]> = LockIsolated([]))
        -> TestStoreOf<SetupFeature> {
        let store = TestStore(initialState: SetupFeature.State(firstKid: first, calendar: calendar)) {
            SetupFeature()
        } withDependencies: { [school, international, now, calendar] in
            $0.calendar = calendar
            $0.date.now = now
            $0.uuid = .incrementing
            $0.schoolDirectory.schools = { [school, international] }
            $0.scheduleStore.replaceFamily = { family in saved.withValue { $0.append(family) } }
            $0.bus.stop = { code in code == "00000" ? BusStop(code: code, name: "Example Stop", road: "Example Rd") : nil }
            $0.bus.arrivals = { _ in [BusArrival(service: "1", minutes: 5, type: .double)] }
            $0.bus.searchStops = { _ in [] }
        }
        store.exhaustivity = .off
        return store
    }

    /// Kid A (8, with a school) and Kid B (4, no school yet) on S1.
    private func family(_ store: TestStoreOf<SetupFeature>) async {
        await store.send(.task)
        await store.receive(\.directoryLoaded)
        await store.send(.nameChanged(first, "Kid A"))
        await store.send(.ageChanged(first, "8"))
        await store.send(.addKidTapped)
        await store.send(.nameChanged(store.state.kids[1].id, "Kid B"))
        await store.send(.ageChanged(store.state.kids[1].id, "4"))
    }

    /// On S2: Kid B (4) stays at home; back on Kid A's tab.
    private func kidBAtHome(_ store: TestStoreOf<SetupFeature>) async {
        await store.send(.schoolTabTapped(store.state.kids[1].id))
        await store.send(.goesToTapped(.home))
        await store.send(.schoolTabTapped(first))
    }

    func testNextNeedsEveryKidsNameAndAge() async {
        let store = store()
        XCTAssertFalse(store.state.canGoNext)
        await store.send(.nameChanged(first, "Kid A"))
        XCTAssertFalse(store.state.canGoNext, "no age yet")
        await store.send(.ageChanged(first, "8 years"))
        XCTAssertEqual(store.state.kids[0].ageText, "8")
        XCTAssertTrue(store.state.canGoNext)
        await store.send(.addKidTapped)
        XCTAssertFalse(store.state.canGoNext, "the new card is empty")
        await store.send(.nextTapped)
        XCTAssertEqual(store.state.step, .family, "Next does nothing while it is off")
    }

    func testNewKidGetsTheNextFreeColourAndPickingATakenOneSwaps() async {
        let store = store()
        await store.send(.addKidTapped)
        let second = store.state.kids[1].id
        XCTAssertEqual(store.state.kids.map(\.colorIndex), [0, 1], "first blue, second orange")
        await store.send(.colourTapped(first, 1))
        XCTAssertEqual(store.state.kids[id: first]?.colorIndex, 1)
        XCTAssertEqual(store.state.kids[id: second]?.colorIndex, 0, "two kids never share a colour")
        await store.send(.colourTapped(second, 3))
        XCTAssertEqual(store.state.kids.map(\.colorIndex), [1, 3])
    }

    func testAtMostFourKidsAndTheFirstCardStays() async {
        let store = store()
        for _ in 0..<5 { await store.send(.addKidTapped) }
        XCTAssertEqual(store.state.kids.count, 4)
        XCTAssertEqual(Set(store.state.kids.map(\.colorIndex)), [0, 1, 2, 3])
        await store.send(.removeKidTapped(first))
        XCTAssertEqual(store.state.kids.count, 4)
        await store.send(.removeKidTapped(store.state.kids[3].id))
        XCTAssertEqual(store.state.kids.count, 3)
    }

    func testSchoolSearchPicksAndPrefillsHoursFromTheWebsite() async {
        let store = store()
        await family(store)
        await store.send(.nextTapped)
        XCTAssertEqual(store.state.step, .school)
        XCTAssertFalse(store.state.canGoNext)
        await store.send(.schoolTextChanged("e"))
        XCTAssertEqual(store.state.schoolCaption, "Type your school's name", "the list opens from 2 letters")
        await store.send(.schoolTextChanged("exam"))
        XCTAssertEqual(store.state.tabKid?.school.matches.map(\.id), ["example-international", "example-primary"])
        XCTAssertEqual(store.state.schoolCaption, "Tap your school")
        await store.send(.schoolPicked(school))
        let picked = store.state.tabKid?.school
        XCTAssertEqual([picked?.start, picked?.end, picked?.arriveBy, picked?.latest], [450, 810, 450, 460])
        XCTAssertEqual(picked?.hoursSource, "From the school website, checked 9 Nov")
        XCTAssertEqual(picked?.termsRow, .check(isOn: true))
        XCTAssertEqual(store.state.schoolCaption, "MOE primary · Example Town")
        XCTAssertFalse(store.state.canGoNext, "Kid B (4) has no pick yet")
        await kidBAtHome(store)
        XCTAssertTrue(store.state.canGoNext)
        await store.send(.timeChanged(.latest, 465))
        XCTAssertNil(store.state.tabKid?.school.hoursSource, "editing a value removes the source caption")
    }

    func testSchoolNotInTheListAsksAboutTermsAndOwnDatesShowTheBreaks() async {
        let store = store()
        await family(store)
        await store.send(.nextTapped)
        await store.send(.schoolTextChanged("zz"))
        XCTAssertEqual(store.state.schoolCaption, "No school with that name")
        await store.send(.notInListTapped)
        XCTAssertEqual(store.state.tabKid?.school.name, "zz")
        XCTAssertEqual(store.state.tabKid?.school.termsRow, .ask(answer: nil))
        await store.send(.moeAnswered(true))
        XCTAssertEqual(store.state.tabKid?.school.usesMoeTerms, true)
        await store.send(.schoolPicked(international))
        XCTAssertEqual(store.state.tabKid?.school.termsRow, .ownDates(breaks: 3))
        XCTAssertEqual(store.state.termsCaption, "3 breaks from the school website")
        XCTAssertEqual(store.state.tabKid?.school.usesMoeTerms, false)
        XCTAssertNil(store.state.tabKid?.school.start, "nothing known: the fields stay empty")
    }

    func testKidsWithoutASchoolSkipGettingThereAndBackKeepsValues() async {
        let store = store()
        await family(store)
        await store.send(.nextTapped)
        XCTAssertEqual(store.state.tabKid?.goesTo, .school, "School is picked from 7")
        await store.send(.schoolTabTapped(store.state.kids[1].id))
        XCTAssertNil(store.state.tabKid?.goesTo, "nothing is picked under 7")
        await store.send(.goesToTapped(.home))
        XCTAssertEqual(store.state.atHomeLine, "Kid B is at home in the day.")
        await store.send(.schoolTabTapped(first))
        await store.send(.schoolPicked(school))
        await store.send(.nextTapped)
        XCTAssertEqual(store.state.step, .gettingThere(0))
        XCTAssertEqual(store.state.goingKid?.id, first, "only Kid A goes to school")
        await store.send(.nextTapped)
        XCTAssertEqual(store.state.step, .almostDone)
        await store.send(.backTapped)
        await store.send(.backTapped)
        XCTAssertEqual(store.state.step, .school)
        XCTAssertEqual(store.state.tabKid?.school.picked, school, "going back keeps every value")
    }

    func testNoSchoolKidsGoStraightToAlmostDone() async {
        let store = store()
        await store.send(.nameChanged(first, "Kid B"))
        await store.send(.ageChanged(first, "4"))
        await store.send(.nextTapped)
        XCTAssertFalse(store.state.canGoNext, "every kid needs a pick")
        await store.send(.goesToTapped(.home))
        XCTAssertTrue(store.state.canGoNext)
        await store.send(.nextTapped)
        XCTAssertEqual(store.state.step, .almostDone)
    }

    /// Preschool: a typed name, days and drop-off / pick-up; a trip in S3; no MOE row.
    func testPreschoolIsTypedAndGetsATrip() async {
        let saved = LockIsolated<[ScheduleSnapshot]>([])
        let store = store(saved: saved)
        await store.send(.nameChanged(first, "Kid B"))
        await store.send(.ageChanged(first, "3"))
        await store.send(.nextTapped)
        await store.send(.goesToTapped(.preschool))
        await store.send(.schoolTextChanged("Example Preschool"))
        XCTAssertTrue(store.state.tabKid?.school.matches.isEmpty ?? false, "no list for preschools")
        XCTAssertNil(store.state.tabKid?.school.termsRow)
        XCTAssertFalse(store.state.canGoNext)
        await store.send(.timeChanged(.start, 480))
        await store.send(.timeChanged(.end, 720))
        XCTAssertTrue(store.state.canGoNext)
        await store.send(.nextTapped)
        XCTAssertEqual(store.state.step, .gettingThere(0))
        await store.send(.wayPicked(.walk))
        await store.send(.nextTapped)
        await store.send(.nextTapped)
        await store.receive(\.delegate.finished)
        let kid = saved.value.first?.kids.first
        XCTAssertEqual(kid?.school?.kind, .preschool)
        XCTAssertEqual(kid?.school?.name, "Example Preschool")
        XCTAssertEqual(saved.value.first?.routines.first?.blocks.first { $0.kind == .school }?.title, "Preschool")
    }

    /// A debug link over an existing family: Start asks first, and Cancel saves nothing.
    func testStartOverAFamilyAsksFirst() async {
        let saved = LockIsolated<[ScheduleSnapshot]>([])
        let store = store(saved: saved)
        await store.send(.nameChanged(first, "Kid B"))
        await store.send(.ageChanged(first, "4"))
        await store.send(.nextTapped)
        await store.send(.goesToTapped(.home))
        await store.send(.nextTapped)
        var state = store.state
        state.replacesFamily = true
        let asking = TestStore(initialState: state) { SetupFeature() } withDependencies: { [calendar, now] in
            $0.calendar = calendar
            $0.date.now = now
            $0.uuid = .incrementing
            $0.scheduleStore.replaceFamily = { family in saved.withValue { $0.append(family) } }
        }
        asking.exhaustivity = .off
        await asking.send(.nextTapped)
        XCTAssertTrue(asking.state.isConfirmingReplace)
        await asking.send(.replaceCancelled)
        XCTAssertTrue(saved.value.isEmpty)
        await asking.send(.nextTapped)
        await asking.send(.replaceConfirmed)
        await asking.receive(\.delegate.finished)
        XCTAssertEqual(saved.value.count, 1)
    }

    func testStartSavesTheWholeFamilyOnce() async {
        let saved = LockIsolated<[ScheduleSnapshot]>([])
        let store = store(saved: saved)
        await family(store)
        await store.send(.faceTapped(first, "kidGirl"))
        await store.send(.nextTapped)
        await kidBAtHome(store)
        await store.send(.schoolPicked(school))
        await store.send(.nextTapped)
        await store.send(.stopSearch(.textChanged("00000")))
        await store.receive(\.stopSearch.stopLooked)
        await store.send(.serviceTapped("1"))
        await store.send(.walkChanged(8))
        await store.send(.nextTapped)
        XCTAssertEqual(store.state.step, .almostDone)
        XCTAssertTrue(saved.value.isEmpty, "nothing is saved before Start")
        await store.send(.nextTapped)
        XCTAssertFalse(store.state.canGoNext, "no second save while saving")
        await store.receive(\.saved)
        await store.receive(\.delegate.finished)
        await store.send(.nextTapped)
        await store.finish()
        XCTAssertEqual(saved.value.count, 1, "a second tap, while saving or after, saves nothing")
        let family = saved.value[0]
        XCTAssertEqual(family.kids.map(\.name), ["Kid A", "Kid B"])
        XCTAssertEqual(family.kids[0].face, "kidGirl")
        XCTAssertEqual(family.kids[1].face, "", "a face not picked shows the colour dot")
        XCTAssertEqual(family.kids[0].school?.directoryID, "example-primary")
        XCTAssertNil(family.kids[1].school)
        XCTAssertEqual(family.kids[0].school?.latest, 460, "Latest stays on the school record")
        XCTAssertEqual(family.kids[0].school?.lateGrace, 10)
        XCTAssertEqual(family.busPlans, [BusPlan(kid: first, stop: "00000", services: ["1"], walk: 8, ride: 10,
                                                 lateGrace: 10)])
        XCTAssertEqual(family.routines.count, 6)
        XCTAssertEqual(Set(family.routines.map(\.from)), [Day(year: 2026, month: 1, day: 1)])
        let schoolBlock = family.routines.first { $0.kid == first && $0.dayType == .weekday }?
            .blocks.first { $0.kind == .school }
        XCTAssertEqual(schoolBlock?.trip, Trip(way: .bus, leaveBefore: 20), "walk 8 + ride 10, up to 5")
        XCTAssertEqual(family.missions.filter { $0.kid == first }.count, 6)
    }

    func testCarNeedsOnlyTheLeaveTime() async {
        let saved = LockIsolated<[ScheduleSnapshot]>([])
        let store = store(saved: saved)
        await family(store)
        await store.send(.nextTapped)
        await kidBAtHome(store)
        await store.send(.schoolPicked(school))
        await store.send(.nextTapped)
        await store.send(.wayPicked(.car))
        await store.send(.leaveChanged(15))
        XCTAssertEqual(store.state.leaveCaption, "before · 7:15 am")
        await store.send(.nextTapped)
        XCTAssertEqual(store.state.summaryWay?.detail, "Leave 15 min before")
        await store.send(.nextTapped)
        await store.receive(\.delegate.finished)
        XCTAssertEqual(saved.value.first?.busPlans, [])
    }
}
