import DesignSystem
import Domain
import Foundation
import Home
import XCTest

final class HomeModelTests: XCTestCase {
    private func slot(_ title: String, _ kind: SlotKind, _ start: Int, _ end: Int,
                      source: Slot.Source = .routine) -> Slot {
        Slot(title: title, iconName: "actPlay", kind: kind, start: start, end: end, source: source, showsStar: false)
    }

    private lazy var day: [Slot] = [
        slot("Sleep", .sleep, 0, 420), slot("Breakfast", .morning, 420, 465), slot("School", .school, 480, 900),
        slot("Play", .play, 900, 930), slot("Swimming", .afterSchool, 930, 990, source: .weekly(UUID())),
        slot("Play", .play, 990, 1080), slot("Dinner", .dinner, 1080, 1140), slot("Sleep", .sleep, 1230, 1440),
    ]

    /// A free-time slot (board A1, 16:00–17:00 on a school day): plain paper, no picture, named like a gap.
    private var freeDay: [Slot] {
        [slot("Snack", .play, 900, 960),
         Slot(title: "Free time", iconName: "", kind: .free, start: 960, end: 1020, source: .routine, showsStar: false),
         slot("Play", .play, 1020, 1110)]
    }

    func testFreeSectorHasNoPicture() {
        let free = HomeModel.sectors(freeDay, minute: 990)[1]
        XCTAssertEqual(free.style, .free)
        XCTAssertNil(free.iconName)
        XCTAssertTrue(free.isCurrent)
    }

    func testEverySlotKindHasAClockStyle() {
        for kind in SlotKind.allCases {
            let sector = HomeModel.sectors([slot("Any", kind, 0, 60)], minute: 0)[0]
            XCTAssertEqual(sector.style.rawValue, kind.rawValue)
        }
    }

    func testSectorsMarkCurrentAndPriority() {
        let sectors = HomeModel.sectors(day, minute: 945)
        XCTAssertEqual(sectors.filter(\.isCurrent).map(\.start), [930])
        XCTAssertEqual(sectors.first { $0.start == 930 }?.priority, 1)
        XCTAssertEqual(sectors.first { $0.start == 930 }?.style, .afterSchool)
    }

    // MARK: Now and next on home (one rule, 2026-11-08)

}
