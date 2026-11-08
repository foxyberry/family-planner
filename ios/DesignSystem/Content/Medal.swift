import KitArt
import Strings
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
            .accessibilityLabel(label)
    }

    private var label: String {
        switch kind {
        case .gold: L10n.tr("medal.gold")
        case .silver: L10n.tr("medal.silver")
        case .bronze: L10n.tr("medal.bronze")
        }
    }
}

/// A medal that drops in and swings the first time it shows (board 0g2); Reduce Motion fades it in.
/// `dropsIn` false shows it at rest (snapshots, a kid who was ready before the screen opened).
public struct DroppingMedal: View {
    private let kind: MedalKind
    private let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: Bool

    public init(_ kind: MedalKind, size: CGFloat, dropsIn: Bool = true) {
        self.kind = kind
        self.size = size
        _shown = State(initialValue: !dropsIn)
    }

    public var body: some View {
        Medal(kind, size: size)
            .rotationEffect(.degrees(reduceMotion || shown ? 0 : -24), anchor: .top)
            .offset(y: reduceMotion || shown ? 0 : -size * 1.2)
            .opacity(shown ? 1 : 0)
            .onAppear {
                withAnimation(reduceMotion ? .easeIn(duration: 0.3) : .interpolatingSpring(stiffness: 120, damping: 7)) {
                    shown = true
                }
            }
            .allowsHitTesting(false)
    }
}

/// The medal badge on a kid's progress ring (board A3): 0.47 of the ring, overlapping its lower
/// right (x 48–84, y 46–82 in a 76 ring frame), dropping in when it first shows.
public struct MedalBadge: View {
    private let kind: MedalKind
    private let ring: CGFloat
    private let dropsIn: Bool

    public init(_ kind: MedalKind, ring: CGFloat, dropsIn: Bool = true) {
        self.kind = kind
        self.ring = ring
        self.dropsIn = dropsIn
    }

    public var body: some View {
        DroppingMedal(kind, size: ring * 0.47, dropsIn: dropsIn)
            .offset(x: ring * 48 / 76, y: ring * 46 / 76)
            .frame(width: ring, height: ring, alignment: .topLeading)
    }
}
