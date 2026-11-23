import Domain
import XCTest

/// Issue 024: a kid's missions live in bundles; the Morning routine's id follows the kid.
final class BundlesTests: XCTestCase {
    func testTheMorningRoutineIdFollowsTheKid() {
        let a = MissionBundle.morningID(for: SeedData.kidA.id), b = MissionBundle.morningID(for: SeedData.kidB.id)
        XCTAssertEqual(a, MissionBundle.morningID(for: SeedData.kidA.id))
        XCTAssertNotEqual(a, b)
        XCTAssertNotEqual(a, SeedData.kidA.id)
    }

    func testMissionsBecomeOneMorningRoutinePerKidInOrder() {
        let bundles = MissionBundle.mornings(from: SeedData.missions.reversed())
        XCTAssertEqual(bundles.count, 2)
        XCTAssertTrue(bundles.allSatisfy(\.isMorning))
        let kidA = bundles.first { $0.kid == SeedData.kidA.id }
        XCTAssertEqual(kidA?.missions.map(\.order), kidA?.missions.map(\.order).sorted())
        XCTAssertEqual(kidA?.missions.count, SeedData.missions.filter { $0.kid == SeedData.kidA.id }.count)
    }
}
