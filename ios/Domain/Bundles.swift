import Foundation
import Strings

/// A named set of a kid's missions that events pick for their lists (spec "Morning data", issue 024):
/// "Morning routine", "Swim day". At most `Mission.most` missions, kept in circle order.
public struct MissionBundle: Identifiable, Hashable, Codable, Sendable {
    public var id: UUID
    public var kid: Kid.ID
    public var name: String
    public var missions: [Mission]

    public init(id: UUID, kid: Kid.ID, name: String, missions: [Mission]) {
        self.id = id
        self.kid = kid
        self.name = name
        self.missions = missions.sorted { $0.order < $1.order }
    }

    /// The kid's "Morning routine": the bundle the missions of before bundles (C5's one list) became.
    /// Its id comes from the kid's, so every store and the seed name the same bundle.
    public static func morning(kid: Kid.ID, missions: [Mission]) -> MissionBundle {
        MissionBundle(id: morningID(for: kid), kid: kid, name: L10n.tr("bundle.morning"),
                      missions: missions.filter { $0.kid == kid })
    }

    /// The Morning routine's id for a kid: the kid's id with its first byte flipped.
    public static func morningID(for kid: Kid.ID) -> UUID {
        var bytes = kid.uuid
        bytes.0 ^= 0xFF
        return UUID(uuid: bytes)
    }

    public var isMorning: Bool { id == Self.morningID(for: kid) }

    /// One Morning routine per kid that has missions, in the kids' first-seen order.
    public static func mornings(from missions: [Mission]) -> [MissionBundle] {
        var kids: [Kid.ID] = []
        for mission in missions where !kids.contains(mission.kid) { kids.append(mission.kid) }
        return kids.map { morning(kid: $0, missions: missions) }
    }
}
