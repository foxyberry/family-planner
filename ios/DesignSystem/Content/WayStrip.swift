import CrayonKit
import KitArt
import SwiftUI

/// The way to the next outing (board A2-MVP, "Way strip"): home on its stem at the left, the
/// destination on its stem at the right, a crayon road between them, and the mover (bus, car,
/// taxi, shoe) placed by the clock (`progress` 0…1, from State). A small card names the outing.
/// By bus the road has stops and the home stem reads "Our stop"; otherwise it reads "Home".
public struct WayStrip: View {
    private let destination: KitSlot
    private let mover: KitSlot
    private let progress: Double
    private let homeLabel: String
    private let showsStops: Bool
    private let cardTitle: String
    private let cardCaption: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(destination: KitSlot, mover: KitSlot, progress: Double, homeLabel: String, showsStops: Bool,
                cardTitle: String, cardCaption: String) {
        self.destination = destination
        self.mover = mover
        self.progress = min(max(progress, 0), 1)
        self.homeLabel = homeLabel
        self.showsStops = showsStops
        self.cardTitle = cardTitle
        self.cardCaption = cardCaption
    }

    public var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width, height = geometry.size.height
            let roadY = height * 0.72, left: CGFloat = 120, right = width - 120
            ZStack(alignment: .topLeading) {
                road(from: left, to: right, y: roadY)
                stem(KitIcon(.home, size: 104), label: homeLabel, x: left, roadY: roadY)
                stem(KitIcon(destination, size: 104), label: nil, x: right, roadY: roadY)
                KitIcon(mover, size: 96)
                    .phaseAnimator(reduceMotion ? [0.0] : [-2.0, 2.0]) { view, angle in
                        view.rotationEffect(.degrees(angle), anchor: .bottom)
                    } animation: { _ in .easeInOut(duration: 0.9) }
                    .position(x: left + (right - left) * progress, y: roadY - 44)
                card.position(x: width / 2, y: Spacing.xl)
            }
        }
        .accessibilityElement(children: .ignore)
    }

    private func road(from left: CGFloat, to right: CGFloat, y: CGFloat) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: left, y: y))
                path.addLine(to: CGPoint(x: right, y: y))
            }
            .stroke(CrayonPalette.ringTrack.color, style: StrokeStyle(lineWidth: 36, lineCap: .round))
            Path { path in
                path.move(to: CGPoint(x: left, y: y))
                path.addLine(to: CGPoint(x: right, y: y))
            }
            .stroke(CrayonColor.marker, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [14, 14]))
            if showsStops {
                ForEach(1..<4, id: \.self) { index in
                    Circle().fill(CrayonColor.card)
                        .overlay(Circle().stroke(CrayonColor.marker, lineWidth: 3))
                        .frame(width: 20, height: 20)
                        .position(x: left + (right - left) * CGFloat(index) / 4, y: y)
                }
            }
        }
    }

    /// A picture on a short stem above the road, with an optional label under the road.
    private func stem(_ picture: some View, label: String?, x: CGFloat, roadY: CGFloat) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: x, y: roadY - 60))
                path.addLine(to: CGPoint(x: x, y: roadY))
            }
            .stroke(CrayonColor.marker, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            picture.position(x: x, y: roadY - 60 - 52)
            if let label {
                Text(label).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                    .fixedSize()
                    .position(x: x, y: roadY + 48)
            }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(cardTitle).crayonType(.head).foregroundStyle(CrayonColor.ink)
            Text(cardCaption).crayonType(.caption).foregroundStyle(CrayonColor.softText)
        }
        .padding(.horizontal, Spacing.m)
        .padding(.vertical, Spacing.sm)
        .crayonBackground(.roundedRect(cornerRadius: 18), fill: CrayonStyle.paper, seed: CrayonStyle.Seed.card + 21)
        .fixedSize()
    }
}
