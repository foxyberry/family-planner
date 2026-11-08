import CoreGraphics
import Foundation
import KitArt
import XCTest

/// Spec "Picture rigs": the bundled rigs decode, every run image exists, and every move is at
/// rest at the start and the end of a play.
final class KitRigTests: XCTestCase {
    private let rigs = KitRigs.shared

    func testBundledRigsDecode() {
        XCTAssertEqual(rigs.riggedSlots.count, 33)
        XCTAssertEqual(rigs.scale, 1.5)
        let bus = rigs.rig(for: .busSingle)
        XCTAssertEqual(bus?.runs.map(\.part), ["body", "back wheel", "front wheel"])
        XCTAssertEqual(bus?.parts["back wheel"]?.moves, [.spin(degrees: 360)])
        XCTAssertEqual(rigs.fallback.parts["all"]?.moves, [.hop(units: 14)])
    }

    func testEveryRunImageIsInTheCatalog() {
        for name in rigs.riggedSlots {
            guard let slot = KitSlot(rawValue: name), let rig = rigs.rig(for: slot) else {
                return XCTFail("\(name) is not a slot")
            }
            for run in rig.runs {
                XCTAssertNotNil(BundledKitArt.publicRunImage(named: run.image), run.image)
            }
        }
    }

    func testUnknownMoveFailsLoudly() {
        let json = #"{"default":{"parts":[]},"rigs":{"sun":{"runs":[],"parts":{"a":{"origin":[0,0],"moves":[{"type":"wobble"}]}}}}}"#
        XCTAssertThrowsError(try KitRigs(json: Data(json.utf8)))
    }

    func testEveryMoveIsAtRestAtTheStartAndTheEnd() {
        let moves: [KitRig.Move] = [.rock(degrees: 8, times: 2), .bob(units: 6, times: 2), .slide(units: 5, times: 1),
                                    .rise(units: 10), .fall(units: 10), .press(units: 6, delay: 90), .blink,
                                    .flicker, .twinkle, .hop(units: 14)]
        for move in moves {
            for time in [0, RigMotion.duration] {
                let pose = RigMotion.pose([move], at: time, scale: 1.5)
                XCTAssertEqual(pose.rotation, 0, accuracy: 0.001, "\(move) at \(time)")
                XCTAssertEqual(pose.offset.width, 0, accuracy: 0.001, "\(move) at \(time)")
                XCTAssertEqual(pose.offset.height, 0, accuracy: 0.001, "\(move) at \(time)")
                XCTAssertEqual(pose.scaleY, 1, accuracy: 0.001, "\(move) at \(time)")
                XCTAssertEqual(pose.opacity, 1, accuracy: 0.001, "\(move) at \(time)")
            }
        }
        // A spin ends a whole turn round, which looks like rest.
        XCTAssertEqual(RigMotion.pose([.spin(degrees: 360)], at: RigMotion.duration, scale: 1).rotation, 360)
    }

    func testScaleGrowsRockButNotSpin() {
        let quarter = RigMotion.duration / 8   // a rock with times 2 peaks at 1/8 of the play
        XCTAssertEqual(RigMotion.pose([.rock(degrees: 8, times: 2)], at: quarter, scale: 1.5).rotation, 12, accuracy: 0.01)
        XCTAssertEqual(RigMotion.pose([.spin(degrees: 360)], at: RigMotion.duration / 2, scale: 1.5).rotation,
                       RigMotion.pose([.spin(degrees: 360)], at: RigMotion.duration / 2, scale: 1).rotation)
    }

    func testHopLandsWithASquash() {
        let landing = RigMotion.pose([.hop(units: 14)], at: RigMotion.duration * 0.9, scale: 1)
        XCTAssertEqual(landing.scaleY, 0.95, accuracy: 0.001)
        let top = RigMotion.pose([.hop(units: 14)], at: RigMotion.duration * 0.4, scale: 1)
        XCTAssertEqual(top.offset.height, -14, accuracy: 0.001)
    }

    /// Backlog N1a: on the map and the way strip, every bus turns two wheel parts.
    func testEveryBusHasTwoWheelParts() throws {
        for slot in [KitSlot.busDouble, .busSingle, .busMini, .busShuttle] {
            let rig = try XCTUnwrap(KitRigs.shared.rig(for: slot), "\(slot)")
            XCTAssertEqual(rig.parts.keys.filter { $0.hasSuffix("wheel") }.sorted(), ["back wheel", "front wheel"], "\(slot)")
            XCTAssertTrue(rig.runs.contains { $0.part == "back wheel" } && rig.runs.contains { $0.part == "front wheel" })
        }
    }
}
