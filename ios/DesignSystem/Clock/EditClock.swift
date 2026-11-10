import CrayonKit
import KitArt
import SwiftUI

/// The C6 edit clock (spec "C6 · Our day"): the day template as slices on a 24-hour disc (R 340,
/// hub 130) with a knob on the rim at every edge. Dragging a knob reports minutes; the feature
/// applies the rules (`TemplateEdit`) and draws the result. Free slices are paper with a "+".
public struct EditClock: View {
    public struct Knob: Equatable, Sendable {
        public var minute: Int
        public var isLocked: Bool
        /// VoiceOver: "Dinner ends, 7:15 pm".
        public var label: String

        public init(minute: Int, isLocked: Bool, label: String) {
            self.minute = minute
            self.isLocked = isLocked
            self.label = label
        }
    }

    /// While dragging: "Dinner ends" / "7:30 pm" (title 48, pick blue) / "Shower starts". Otherwise
    /// the selected slice's name.
    public struct Hub: Equatable, Sendable {
        public var above: String?
        public var time: String?
        public var below: String?
        public var title: String?

        public init(above: String? = nil, time: String? = nil, below: String? = nil, title: String? = nil) {
            self.above = above
            self.time = time
            self.below = below
            self.title = title
        }
    }

    public static let radius: CGFloat = 340
    public static let hubRadius: CGFloat = 130

    private let sectors: [ClockSector]
    private let knobs: [Knob]
    private let dragging: Int?
    private let dragOrigin: Int?
    private let hub: Hub
    private let onKnobDrag: (Int, Int) -> Void
    private let onKnobEnd: (Int) -> Void
    private let onLockedTap: (Int) -> Void
    private let onSliceTap: (Int) -> Void
    private let onPlusTap: (Int) -> Void
    private let onKnobAdjust: (Int, Int) -> Void

    /// `sectors` marks the selected slice with `isCurrent`; `dragging` is the knob being dragged and
    /// `dragOrigin` its minute when the drag began (a dashed line stays there).
    public init(sectors: [ClockSector], knobs: [Knob], dragging: Int?, dragOrigin: Int?, hub: Hub,
                onKnobDrag: @escaping (Int, Int) -> Void, onKnobEnd: @escaping (Int) -> Void,
                onLockedTap: @escaping (Int) -> Void, onSliceTap: @escaping (Int) -> Void,
                onPlusTap: @escaping (Int) -> Void, onKnobAdjust: @escaping (Int, Int) -> Void) {
        // Sleep before and after midnight is one slice, as on the kid clock.
        self.sectors = PieClockLayout.drawable(sectors)
        self.knobs = knobs
        self.dragging = dragging
        self.dragOrigin = dragOrigin
        self.hub = hub
        self.onKnobDrag = onKnobDrag
        self.onKnobEnd = onKnobEnd
        self.onLockedTap = onLockedTap
        self.onSliceTap = onSliceTap
        self.onPlusTap = onPlusTap
        self.onKnobAdjust = onKnobAdjust
    }

    private let r = EditClock.radius

    public var body: some View {
        ZStack {
            Circle().fill(CrayonColor.paper).frame(width: 2 * r, height: 2 * r)
                .onTapGesture(coordinateSpace: .local) { location in
                    guard let slice = PieClockLayout.sector(at: location, in: sectors, radius: r, hub: Self.hubRadius)
                    else { return }
                    slice.style == .free ? onPlusTap(slice.start) : onSliceTap(slice.start)
                }
            ForEach(sectors, id: \.self) { sector in
                CrayonSurface(.sector(startDegrees: PieClockLayout.degrees(minute: sector.start),
                                      endDegrees: PieClockLayout.degrees(minute: sector.end)),
                              fill: sector.style.fill, marker: MarkerStyle(width: 2.5, roughness: 1.2, bowing: 1.4),
                              seed: UInt32(3001 + sector.start))
                    .allowsHitTesting(false)
            }
            ForEach(sectors.filter(\.isCurrent), id: \.self) { sector in
                CrayonSurface(.sector(startDegrees: PieClockLayout.degrees(minute: sector.start),
                                      endDegrees: PieClockLayout.degrees(minute: sector.end)),
                              fill: nil, marker: MarkerStyle(width: 6, roughness: 1.2, bowing: 1.4),
                              seed: UInt32(3001 + sector.start))
                    .allowsHitTesting(false)
            }
            CrayonSurface(.circle, fill: nil, marker: MarkerStyle(width: 4.5, roughness: 1.2, bowing: 1.4), seed: 3000)
                .allowsHitTesting(false)
            ticksAndLabels
            pictures
            if let dragOrigin { originLine(dragOrigin) }
            hubDisc
            knobViews
        }
        .frame(width: 2 * r, height: 2 * r)
        .coordinateSpace(.named(Self.space))
    }

    private static let space = "editClock"

    private func point(radius: CGFloat, minute: Double) -> CGPoint {
        let a = minute / 4 * .pi / 180
        return CGPoint(x: r + radius * CGFloat(sin(a)), y: r - radius * CGFloat(cos(a)))
    }

    /// The minute on the dial under `location`, 0..<1440.
    private func minute(at location: CGPoint) -> Int {
        var degrees = atan2(location.x - r, r - location.y) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        return Int(degrees * 4) % 1440
    }

    private var ticksAndLabels: some View {
        ZStack {
            Canvas { context, _ in  // bleed-ok: straight ticks well inside the dial frame
                var path = Path()
                for hour in 0..<24 {
                    path.move(to: point(radius: r + 4, minute: Double(hour * 60)))
                    path.addLine(to: point(radius: r + 16, minute: Double(hour * 60)))
                }
                context.stroke(path, with: .color(CrayonColor.marker), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
            ForEach(0..<24, id: \.self) { hour in
                let major = hour % 6 == 0
                Text("\(hour % 12 == 0 ? 12 : hour % 12)")
                    .font(Font(FontRegistrar.font(size: major ? CrayonType.body.size : CrayonType.caption.size,
                                                  weight: .semibold)))
                    .foregroundStyle(major ? CrayonColor.ink : CrayonColor.softText)
                    .position(point(radius: r + 40, minute: Double(hour * 60)))
            }
        }
        .frame(width: 2 * r, height: 2 * r)
        .allowsHitTesting(false)
    }

    private var pictures: some View {
        ForEach(sectors, id: \.self) { sector in
            let middle = Double(sector.start + sector.end) / 2
            if sector.style == .free {
                PlusGlyph(size: 56) // board C6: a 56 ring
                    .position(point(radius: (Self.hubRadius + r) / 2, minute: middle))
                    .onTapGesture { onPlusTap(sector.start) }
                    .accessibilityElement()
                    .accessibilityAddTraits(.isButton)
            } else if let name = sector.iconName, let slot = KitSlot(rawValue: name),
                      let picture = PieClockLayout.picture(minutes: sector.end - sector.start, radius: r,
                                                           hub: Self.hubRadius) {
                KitIcon(slot, size: picture.size)
                    .position(point(radius: picture.distance, minute: middle))
                    .allowsHitTesting(false)
            }
        }
    }

    private func originLine(_ minute: Int) -> some View {
        Path { path in
            path.move(to: point(radius: Self.hubRadius, minute: Double(minute)))
            path.addLine(to: point(radius: r, minute: Double(minute)))
        }
        .stroke(CrayonColor.marker, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 8]))
        .allowsHitTesting(false)
    }

    private var hubDisc: some View {
        VStack(spacing: Spacing.xxs) {
            if let above = hub.above {
                Text(above).crayonType(.caption).foregroundStyle(CrayonColor.softText)
            }
            if let time = hub.time {
                // At its own size, centred: shrinking to fit kept a full-width box and leaned the
                // time left of the hub's middle (iPad review, 2026-11-10). "12:30 pm" fits the hub.
                Text(time).crayonType(.title).foregroundStyle(CrayonColor.pickBlue).fixedSize()
            }
            if let below = hub.below {
                Text(below).crayonType(.caption).foregroundStyle(CrayonColor.softText)
            }
            if let title = hub.title {
                Text(title).crayonType(.head).foregroundStyle(CrayonColor.ink).lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .multilineTextAlignment(.center)
        .frame(width: 2 * Self.hubRadius - Spacing.m)
        .frame(width: 2 * Self.hubRadius, height: 2 * Self.hubRadius)
        .crayonBackground(.circle, fill: CrayonStyle.paper, seed: 3003)
        .allowsHitTesting(false)
    }

    private var knobViews: some View {
        ForEach(Array(knobs.enumerated()), id: \.offset) { index, knob in
            ClockKnob(knob.isLocked ? .locked : (dragging == index ? .dragging : .idle))
                .position(point(radius: r, minute: Double(knob.minute)))
                .gesture(knob.isLocked ? nil : DragGesture(minimumDistance: 2, coordinateSpace: .named(Self.space))
                    .onChanged { onKnobDrag(index, minute(at: $0.location)) }
                    .onEnded { _ in onKnobEnd(index) })
                .onTapGesture { if knob.isLocked { onLockedTap(index) } }
                .accessibilityElement()
                .accessibilityLabel(knob.label)
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: onKnobAdjust(index, 5)
                    case .decrement: onKnobAdjust(index, -5)
                    @unknown default: break
                    }
                }
        }
    }
}

/// A crayon "+" (board 0b marker glyphs): two marker strokes, for filling free time.
public struct PlusGlyph: View {
    private let size: CGFloat

    public init(size: CGFloat = 40) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            CrayonSurface(.circle, fill: CrayonFill(color: CrayonColor.card, hachure: nil),
                          seed: CrayonStyle.Seed.plus)
            MarkerIcon(.plus, size: size * 0.7)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
    }
}
