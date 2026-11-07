import KitArt
import SwiftUI

public enum MedalKind: Sendable, CaseIterable {
    case gold, silver, bronze

    var slot: KitSlot {
        switch self {
        case .gold: .medalGold
        case .silver: .medalSilver
        case .bronze: .medalBronze
        }
    }
}

/// A gold, silver or bronze medal from the crayon kit.
public struct Medal: View {
    private let kind: MedalKind
    private let size: CGFloat

    public init(_ kind: MedalKind, size: CGFloat) {
        self.kind = kind
        self.size = size
    }

    public var body: some View {
        KitIcon(kind.slot, size: size)
            .accessibilityLabel("\(String(describing: kind).capitalized) medal")
    }
}
