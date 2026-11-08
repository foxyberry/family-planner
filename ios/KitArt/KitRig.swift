import CoreGraphics
import Foundation
import UIKit

/// A picture's rig (spec "Picture rigs", boards 0g3 / 0g3b): the picture split into ordered runs,
/// and the moves of each moving part. Coordinates are in the kit's 240 box.
public struct KitRig: Equatable, Sendable {
    public struct Run: Equatable, Sendable {
        /// The run's image in the kit catalog, `rig-<slot>-<n>`.
        public var image: String
        /// The part this run moves with; `nil` stays still.
        public var part: String?
    }

    public struct Part: Equatable, Sendable {
        /// The pivot, where the part is attached, in the 240 box.
        public var origin: CGPoint
        public var moves: [Move]
    }

    /// The small set of rigid moves. Amounts are in degrees or 240-box units.
    public enum Move: Equatable, Sendable {
        case rock(degrees: Double, times: Int)
        case bob(units: Double, times: Int)
        case slide(units: Double, times: Int)
        case rise(units: Double)
        case fall(units: Double)
        case press(units: Double, delay: Double)
        case spin(degrees: Double)
        case blink
        case flicker
        case twinkle
        case hop(units: Double)
    }

    /// Empty for the default rig: the whole picture is one part.
    public var runs: [Run]
    public var parts: [String: Part]
}

/// The rigs from `make art` (`KitRigs.dataset/rigs.json`), decoded once.
public struct KitRigs: Sendable {
    /// The size the moves are drawn at; the data's value, or 1.5 (spec: shipped at scale 1.5).
    public let scale: Double
    /// The whole-picture hop for a slot without a rig.
    public let fallback: KitRig
    private let rigs: [String: KitRig]

    public static let shared: KitRigs = {
        guard let data = BundledKitArt.publicBundle.flatMap({ NSDataAsset(name: "KitRigs", bundle: $0)?.data }), // copy-ok: asset name
              let rigs = try? KitRigs(json: data) else {
            return KitRigs(scale: 1.5, fallback: KitRigs.hop, rigs: [:])
        }
        return rigs
    }()

    init(scale: Double, fallback: KitRig, rigs: [String: KitRig]) {
        self.scale = scale
        self.fallback = fallback
        self.rigs = rigs
    }

    /// Decodes `rigs.json`; an unknown move type is an error, so a new kit move is never silently dropped.
    public init(json data: Data) throws {
        let file = try JSONDecoder().decode(File.self, from: data)
        scale = file.scale ?? 1.5
        let whole = try file.default.parts.first.map {
            KitRig.Part(origin: CGPoint(x: $0.origin[0], y: $0.origin[1]), moves: try $0.moves.map(Self.move))
        }
        fallback = whole.map { KitRig(runs: [], parts: ["all": $0]) } ?? KitRigs.hop
        rigs = try file.rigs.mapValues { rig in
            KitRig(runs: rig.runs.map { KitRig.Run(image: $0.image, part: $0.part) },
                   parts: try rig.parts.mapValues {
                       KitRig.Part(origin: CGPoint(x: $0.origin[0], y: $0.origin[1]), moves: try $0.moves.map(Self.move))
                   })
        }
    }

    /// The rig for `slot`, or `nil` when the slot plays the whole-picture hop.
    public func rig(for slot: KitSlot) -> KitRig? { rigs[slot.rawValue] }

    /// Every rigged slot's raw value (for tests and the gallery).
    public var riggedSlots: [String] { rigs.keys.sorted() }

    private static let hop = KitRig(runs: [], parts: ["all": KitRig.Part(origin: CGPoint(x: 120, y: 220),
                                                                          moves: [.hop(units: 14)])])

    struct UnknownMove: Error { let type: String }

    private static func move(_ raw: RawMove) throws -> KitRig.Move {
        switch raw.type {
        case "rock": .rock(degrees: raw.deg ?? 0, times: raw.times ?? 1)
        case "bob": .bob(units: raw.px ?? 0, times: raw.times ?? 1)
        case "slide": .slide(units: raw.px ?? 0, times: raw.times ?? 1)
        case "rise": .rise(units: raw.px ?? 0)
        case "fall": .fall(units: raw.px ?? 0)
        case "press": .press(units: raw.px ?? 0, delay: raw.delay ?? 0)
        case "spin": .spin(degrees: raw.deg ?? 360)
        case "blink": .blink
        case "flicker": .flicker
        case "twinkle": .twinkle
        case "hop": .hop(units: raw.px ?? 14)
        default: throw UnknownMove(type: raw.type)
        }
    }

    private struct File: Decodable {
        var scale: Double?
        var `default`: DefaultRig
        var rigs: [String: RawRig]
    }

    private struct DefaultRig: Decodable { var parts: [RawPart] }
    private struct RawRig: Decodable {
        var runs: [RawRun]
        var parts: [String: RawPart]
    }
    private struct RawRun: Decodable {
        var image: String
        var part: String?
    }
    private struct RawPart: Decodable {
        var origin: [Double]
        var moves: [RawMove]
    }
    private struct RawMove: Decodable {
        var type: String
        var deg: Double?
        var px: Double?
        var times: Int?
        var delay: Double?
    }
}
