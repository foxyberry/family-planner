import Domain
import Foundation
import XCTest

/// Spec "Events: one shape for every item": which event a slot is, for its route and its records.
final class MissionRecordsTests: XCTestCase {
    private func slot(_ kind: SlotKind, _ source: Slot.Source) -> Slot {
        Slot(title: "Slot", iconName: "actPlay", kind: kind, start: 450, end: 900, source: source, showsStar: false)
    }

    func testSlotsPointAtTheirEvent() {
        let id = UUID()
        XCTAssertEqual(EventRef(slot(.school, .routine)), .school)
        XCTAssertNil(EventRef(slot(.play, .routine)), "other template blocks have no id yet")
        XCTAssertEqual(EventRef(slot(.afterSchool, .weekly(id))), .item(id))
        XCTAssertEqual(EventRef(slot(.event, .once(id))), .item(id))
    }

    func testRecordsRoundTripAsJSON() throws {
        let day = Day(year: 2026, month: 11, day: 10)
        let marks = WindowMissions(kid: UUID(), date: day, window: .before(.item(UUID())), done: [UUID()])
        let slide = OutingSlide(kid: UUID(), date: day, outing: .school, ready: true, readyAt: 418, medal: .gold)
        XCTAssertEqual(try JSONDecoder().decode(WindowMissions.self, from: JSONEncoder().encode(marks)), marks)
        XCTAssertEqual(try JSONDecoder().decode(OutingSlide.self, from: JSONEncoder().encode(slide)), slide)
    }
}
