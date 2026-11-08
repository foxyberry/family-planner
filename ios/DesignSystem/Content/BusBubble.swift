import CrayonKit
import KitArt
import Strings
import SwiftUI

/// A bus on the map: number plate, minutes away, and how full it is (happy faces).
public struct BusBubble: View {
    private let route: String
    private let minutes: Int
    private let crowd: Crowd?
    private let isMine: Bool
    private let transferTo: String?

    public init(route: String, minutes: Int, crowd: Crowd?, isMine: Bool, transferTo: String?) {
        self.route = route
        self.minutes = minutes
        self.crowd = crowd
        self.isMine = isMine
        self.transferTo = transferTo
    }

    /// Our own bus gets the bigger white plate; a transfer bus a smaller yellow one (never below 24).
    nonisolated public static func plateFontSize(isMine: Bool) -> CGFloat {
        isMine ? 28 : CrayonType.caption.size
    }

    public var body: some View {
        VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                plate(route)
                if let transferTo {
                    Image(systemName: "arrow.right").font(.system(size: 20, weight: .bold))
                    plate(transferTo)
                }
            }
            Text(L10n.tr("duration.min", minutes)).crayonType(.body).monospacedDigit()
            if let crowd {
                HStack(spacing: 4) {
                    ForEach(0..<crowd.happyFaces, id: \.self) { _ in KitIcon(.feelHappy, size: 32) }
                }
                .accessibilityLabel(crowdLabel(crowd))
            }
        }
        .foregroundStyle(CrayonColor.ink)
        .padding(Spacing.s)
        .padding(.bottom, 16)
        .crayonBackground(.speechBubble(tailX: 0.5, tailHeight: 16), fill: CrayonStyle.paper,
                          seed: CrayonStyle.Seed.bubble)
    }

    private func plate(_ number: String) -> some View {
        Text(number)
            .font(.system(size: Self.plateFontSize(isMine: isMine), weight: .heavy, design: .rounded))
            .padding(.horizontal, Spacing.xs)
            .background(RoundedRectangle(cornerRadius: 6).fill(isMine ? CrayonColor.card : CrayonColor.goYellow))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(CrayonColor.marker, lineWidth: 2))
    }

    private func crowdLabel(_ crowd: Crowd) -> String {
        switch crowd {
        case .seats: L10n.tr("bus.crowd.seats")
        case .standing: L10n.tr("bus.crowd.standing")
        case .full: L10n.tr("bus.crowd.full")
        }
    }
}
