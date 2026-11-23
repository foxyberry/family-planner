import Domain
import Foundation
import XCTest

/// Issue 024 (spec "Events: one shape" → Lists): an outing's before and after lists.
final class EventListsTests: XCTestCase {
    private let kidA = SeedData.kidA.id, kidB = SeedData.kidB.id

    private func mission(_ name: String, _ picture: String, kid: UUID, order: Int, days: Set<Weekday> = Set(Weekday.allCases)) -> Mission {
        Mission(id: UUID(), kid: kid, name: name, picture: picture, order: order, days: days)
    }

    private func bring(_ name: String, _ picture: String) -> ItemMission { ItemMission(id: UUID(), name: name, picture: picture) }

    private func slot(_ title: String, _ start: Int, _ end: Int, source: Slot.Source, after: EventRef? = nil,
                      lists: EventLists = EventLists(), bring: [ItemMission] = []) -> Slot {
        Slot(title: title, iconName: "actPlay", kind: .afterSchool, start: start, end: end, source: source, showsStar: false,
             trip: after == nil ? Trip(way: .car, leaveBefore: 10) : nil, after: after, lists: lists, bring: bring)
    }

    /// The kid's bundles' missions by their days, then Bring: its own and the linked events', each picture
    /// once and none a mission already shows; the other kid's bundle is not on this kid's list.
    func testBeforeListIsBundlesThenBringIncludingLinkedEvents() {
        let morning = MissionBundle(id: UUID(), kid: kidA, name: "Morning", missions: [
            mission("Wake up", "sun", kid: kidA, order: 0), mission("Library bag", "backpack", kid: kidA, order: 1, days: [.thursday]),
        ])
        let theirs = MissionBundle(id: UUID(), kid: kidB, name: "Morning", missions: [mission("Milk", "babyBottle", kid: kidB, order: 0)])
        let swimID = UUID()
        let school = slot("School", 450, 900, source: .routine, lists: EventLists(before: [morning.id, theirs.id]),
                          bring: [bring("Backpack", "backpack"), bring("Water", "waterBottle")])
        var swimming = slot("Swimming", 900, 960, source: .weekly(swimID), after: .school,
                            bring: [bring("Swimsuit", "swimsuit"), bring("Water", "waterBottle")])
        swimming.kind = .afterSchool
        var schoolSlot = school
        schoolSlot.kind = .school
        let slots = [schoolSlot, swimming]
        let monday = EventListRules.before(kid: kidA, slot: schoolSlot, in: slots, bundles: [morning, theirs], weekday: .monday)
        XCTAssertEqual(monday.map(\.name), ["Wake up", "Backpack", "Water", "Swimsuit"])
        let thursday = EventListRules.before(kid: kidA, slot: schoolSlot, in: slots, bundles: [morning, theirs], weekday: .thursday)
        XCTAssertEqual(thursday.map(\.name), ["Wake up", "Library bag", "Water", "Swimsuit"], "the backpack shows once")
        XCTAssertEqual(EventListRules.before(kid: kidA, slot: swimming, in: slots, bundles: [morning], weekday: .monday), [],
                       "a linked event's Bring is packed on the chain's first list")
    }

    /// The after list is only on the chain's last event: the kid's after bundles, then the shared missions.
    func testAfterListIsOnTheChainsLastEvent() {
        let home = MissionBundle(id: UUID(), kid: kidA, name: "Home", missions: [mission("Wash hands", "soap", kid: kidA, order: 0)])
        var school = slot("School", 450, 900, source: .routine, lists: EventLists(afterBundles: [home.id]))
        school.kind = .school
        let swimming = slot("Swimming", 900, 960, source: .weekly(UUID()), after: .school,
                            lists: EventLists(afterBundles: [home.id], afterMissions: [bring("Hang swimsuit", "swimsuit")]))
        let slots = [school, swimming]
        XCTAssertEqual(EventListRules.after(kid: kidA, slot: school, in: slots, bundles: [home], weekday: .monday), [])
        XCTAssertEqual(EventListRules.after(kid: kidA, slot: swimming, in: slots, bundles: [home], weekday: .monday).map(\.name),
                       ["Wash hands", "Hang swimsuit"])
        XCTAssertEqual(EventListRules.after(kid: kidB, slot: swimming, in: slots, bundles: [home], weekday: .monday).map(\.name),
                       ["Hang swimsuit"], "the shared missions are every kid's")
        XCTAssertEqual(EventListRules.chainEnd(of: school, in: slots), swimming)
    }

    /// Stored values from before issue 024 load with empty lists; set lists survive a round trip.
    func testListsRoundTripAndOldValuesLoadEmpty() throws {
        var item = SeedData.items(today: Day(year: 2026, month: 11, day: 10), calendar: Calendar(identifier: .gregorian))[0]
        item.lists = EventLists(before: [UUID()], afterBundles: [UUID()], afterMissions: [bring("Unpack", "backpack")], wayHome: .pickup)
        let decoded = try JSONDecoder().decode(ScheduleItem.self, from: JSONEncoder().encode(item))
        XCTAssertEqual(decoded.lists, item.lists)
        var block = SeedData.routines[0].blocks[0]
        block.lists = EventLists(wayHome: .walk)
        XCTAssertEqual(try JSONDecoder().decode(RoutineBlock.self, from: JSONEncoder().encode(block)).lists, block.lists)
        let oldBlock = #"{"title":"School","iconName":"wolfie","kind":"school","start":450,"end":900,"isLocked":true}"#
        XCTAssertEqual(try JSONDecoder().decode(RoutineBlock.self, from: Data(oldBlock.utf8)).lists, EventLists())
    }

    /// Design answer 2026-11-23: the Morning routine goes on School's before list and the first outing of
    /// each weekend template; a list with bundles already is left alone.
    func testTheMorningRoutineGoesOnSchoolAndTheWeekendsFirstOuting() {
        var kid = SeedData.kidA
        kid.school?.lists = nil
        var saturday = SeedData.routines.first { $0.kid == kidA && $0.dayType == .saturday }!
        saturday.blocks.append(RoutineBlock(title: "Class", iconName: "actArt", kind: .afterSchool, start: 600, end: 660,
                                            trip: Trip(way: .car, leaveBefore: 10)))
        let attached = MissionBundle.attachingMorning(to: kid, routines: [saturday])
        let morning = MissionBundle.morningID(for: kidA)
        XCTAssertEqual(attached.kid.school?.lists?.before, [morning])
        XCTAssertEqual(attached.routines[0].blocks.first { $0.title == "Class" }?.lists.before, [morning])
        XCTAssertEqual(SeedData.kidA.school?.lists?.before, [morning], "the seed has it too")
        let again = MissionBundle.attachingMorning(to: attached.kid, routines: attached.routines)
        XCTAssertEqual(again.kid, attached.kid)
        XCTAssertEqual(again.routines, attached.routines)
    }
}
