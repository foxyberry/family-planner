import CoreGraphics
import Synchronization

/// Remembers computed crayon geometry so a view that redraws every second (morning countdown)
/// does not rebuild the same paths. Sizes are rounded to whole points so tiny layout changes
/// share one entry.
final class GeometryCache: Sendable {
    struct Key: Hashable, Sendable {
        let kind: CrayonShapeKind
        let width: Int
        let height: Int
        let seed: UInt32
        let marker: MarkerStyle
        let hachure: HachureStyle?

        init(kind: CrayonShapeKind, size: CGSize, seed: UInt32, marker: MarkerStyle, hachure: HachureStyle?) {
            self.kind = kind
            width = Int(size.width.rounded())
            height = Int(size.height.rounded())
            self.seed = seed
            self.marker = marker
            self.hachure = hachure
        }
    }

    private struct State {
        var entries: [Key: CrayonGeometry] = [:]
        var makeCount = 0
    }

    static let shared = GeometryCache()
    private static let limit = 512
    private let state = Mutex(State())

    init() {}

    func geometry(for key: Key, make: () -> CrayonGeometry) -> CrayonGeometry {
        if let hit = state.withLock({ $0.entries[key] }) { return hit }
        let made = make()
        state.withLock { state in
            if state.entries.count >= Self.limit { state.entries.removeAll(keepingCapacity: true) }
            state.entries[key] = made
            state.makeCount += 1
        }
        return made
    }

    /// How many geometries were built (for tests and performance checks).
    var makeCount: Int { state.withLock { $0.makeCount } }
}
