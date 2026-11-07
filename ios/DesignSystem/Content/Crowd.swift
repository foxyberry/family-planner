/// How full a bus is (LTA "Load": SEA / SDA / LSD), shown as 0–2 happy faces.
public enum Crowd: Sendable, CaseIterable {
    case seats, standing, full

    public var happyFaces: Int {
        switch self {
        case .seats: 2
        case .standing: 1
        case .full: 0
        }
    }
}
