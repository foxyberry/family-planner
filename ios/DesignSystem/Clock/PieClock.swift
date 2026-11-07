import CrayonKit
import KitArt
import SwiftUI

/// The 24-hour crayon pie clock (board A1). The view's frame is the disc (radius 372); hour labels,
/// the moon and the sun sit outside it, so give the clock room around its frame.
public struct PieClock: View {
    public struct Hub: Equatable, Sendable {
        public var title: String?
        public var subtitle: String?

        public init(title: String?, subtitle: String?) {
            self.title = title
            self.subtitle = subtitle
        }
    }

    public static let radius: CGFloat = 372
    static let hubRadius: CGFloat = 152

    private let sectors: [ClockSector]
    private let now: Int?
    private let hub: Hub
    private let holdProgress: Double

    /// `now` is minutes after midnight; `nil` draws no hand (no schedule at all).
    /// `holdProgress` 0...1 draws the grown-up hold ring around the hub.
    public init(sectors: [ClockSector], now: Int?, hub: Hub, holdProgress: Double = 0) {
        self.sectors = PieClockLayout.drawable(sectors)
        self.now = now
        self.hub = hub
        self.holdProgress = holdProgress
    }

    private let r = PieClock.radius

    public var body: some View {
        ZStack {
            ForEach(sectors, id: \.self) { sector in
                CrayonSurface(.sector(startDegrees: PieClockLayout.degrees(minute: sector.start),
                                      endDegrees: PieClockLayout.degrees(minute: sector.end)),
                              fill: sector.style.fill, marker: MarkerStyle(width: 2.5, roughness: 1.2, bowing: 1.4),
                              seed: UInt32(3001 + sector.start))
            }
            ForEach(sectors.filter(\.isCurrent), id: \.self) { sector in
                CrayonSurface(.sector(startDegrees: PieClockLayout.degrees(minute: sector.start),
                                      endDegrees: PieClockLayout.degrees(minute: sector.end)),
                              fill: nil, marker: MarkerStyle(width: 6, roughness: 1.2, bowing: 1.4),
                              seed: UInt32(3001 + sector.start))
            }
            CrayonSurface(.circle, fill: nil, marker: MarkerStyle(width: 4.5, roughness: 1.2, bowing: 1.4), seed: 3000)
            ticks
            labels
            pictures
            if let now { hand(at: now) }
            hubDisc
            if holdProgress > 0 {
                Circle()
                    .trim(from: 0, to: holdProgress)
                    .stroke(CrayonColor.marker, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 320, height: 320)
            }
        }
        .frame(width: 2 * r, height: 2 * r)
    }

    /// The title, then shorter word-prefixes ending in "…", longest first.
    public nonisolated static func hubTitleCandidates(_ title: String) -> [String] {
        let words = title.split(separator: " ")
        guard words.count > 1 else { return [title] }
        return [title] + (1..<words.count).reversed().map { words[0..<$0].joined(separator: " ") + "…" }
    }

    /// A point `radius` from the centre at `degrees` clockwise from 12 o'clock.
    private func point(radius: CGFloat, degrees: Double) -> CGPoint {
        let a = degrees * .pi / 180
        return CGPoint(x: r + radius * CGFloat(sin(a)), y: r - radius * CGFloat(cos(a)))
    }

    private var ticks: some View {
        Canvas { context, _ in
            var path = Path()
            for hour in 0..<24 {
                path.move(to: point(radius: 378, degrees: Double(hour) * 15))
                path.addLine(to: point(radius: 392, degrees: Double(hour) * 15))
            }
            context.stroke(path, with: .color(CrayonColor.marker), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        .frame(width: 2 * r, height: 2 * r)
        .allowsHitTesting(false)
    }

    private var labels: some View {
        ForEach(0..<24, id: \.self) { hour in
            let major = hour % 6 == 0
            Text("\(hour % 12 == 0 ? 12 : hour % 12)")
                .font(Font(FontRegistrar.font(size: major ? 30 : 24, weight: .semibold)))
                .foregroundStyle(major ? CrayonColor.ink : CrayonColor.softText)
                .position(point(radius: 412, degrees: Double(hour) * 15))
        }
        .overlay {
            KitIcon(.actSleep, size: 40).position(x: r, y: r - 412 - 44)
            KitIcon(.sun, size: 44).position(x: r, y: r + 412 + 46)
        }
        .allowsHitTesting(false)
    }

    private var pictures: some View {
        ForEach(sectors, id: \.self) { sector in
            let middle = PieClockLayout.degrees(minute: (sector.start + sector.end) / 2)
            if let name = sector.iconName, let slot = KitSlot(rawValue: name),
               let picture = PieClockLayout.picture(minutes: sector.end - sector.start, radius: r,
                                                    hub: Self.hubRadius) {
                KitIcon(slot, size: picture.size).position(point(radius: picture.distance, degrees: middle))
            }
            if sector.showsStar {
                KitIcon(.star, size: 40).position(point(radius: Self.hubRadius + 36, degrees: middle))
            }
        }
        .allowsHitTesting(false)
    }

    private func hand(at minute: Int) -> some View {
        let degrees = PieClockLayout.degrees(minute: minute)
        return ZStack {
            Path { path in
                path.move(to: point(radius: 154, degrees: degrees))
                path.addLine(to: point(radius: 312, degrees: degrees))
            }
            .stroke(CrayonColor.handRed, style: StrokeStyle(lineWidth: 9, lineCap: .round))
            CrayonSurface(.circle, fill: CrayonFill(color: CrayonColor.handRed, hachure: HachureStyle(degrees: -40)),
                          seed: 3002)
                .frame(width: 48, height: 48)
                .position(point(radius: 336, degrees: degrees))
        }
        .frame(width: 2 * r, height: 2 * r)
        .allowsHitTesting(false)
    }

    private var hubDisc: some View {
        VStack(spacing: Spacing.xs) {
            Text("NOW").crayonType(.caption).foregroundStyle(CrayonColor.softText)
            if let title = hub.title {
                // title 48, then head 36, then head 36 cut at a word with "…"; never wrapped.
                ViewThatFits(in: .horizontal) {
                    Text(title).crayonType(.title).fixedSize()
                    ForEach(Self.hubTitleCandidates(title), id: \.self) { candidate in
                        Text(candidate).crayonType(.head).fixedSize()
                    }
                }
                .foregroundStyle(CrayonColor.ink)
                .frame(maxWidth: 260)
            }
            if let subtitle = hub.subtitle {
                Text(subtitle).crayonType(.body).foregroundStyle(CrayonColor.softText).lineLimit(1)
            }
        }
        .frame(width: 2 * Self.hubRadius, height: 2 * Self.hubRadius)
        .crayonBackground(.circle, fill: CrayonStyle.paper, seed: 3003)
        .accessibilityHidden(true)
    }
}
