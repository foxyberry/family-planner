import CrayonKit
import KitArt
import SwiftUI

/// The G1 edit clock (spec "G1 · Our day: the clock and its rules"): the day template as slices on a 24-hour disc (R 340,
/// hub 130) with a knob on the rim at every edge. Dragging a knob reports minutes; the feature
/// applies the rules (`TemplateEdit`) and draws the result. Free slices are paper with a "+".
public struct EditClock: View {
    public struct Knob: Equatable, Sendable {
        public var minute: Int
        public var isLocked: Bool

        public init(minute: Int, isLocked: Bool) {
            self.minute = minute
            self.isLocked = isLocked
        }
    }

    /// While dragging: "Dinner ends" / "7:30 pm" (title 48, pick blue) / "Shower starts". Otherwise
    /// the selected slice's name.
    public struct Hub: Equatable, Sendable {
        public var above: String?
        public var time: String?
        public var below: String?
        public var title: String?
        /// Board G1g: "Skipped" is a word, not a time: `softText` like the lines around it
        /// (`pickBlue` means a drag in progress).
        public var timeIsMuted: Bool

        public init(above: String? = nil, time: String? = nil, below: String? = nil, title: String? = nil,
                    timeIsMuted: Bool = false) {
            self.timeIsMuted = timeIsMuted
            self.above = above
            self.time = time
            self.below = below
            self.title = title
        }
    }

    /// Board G1: a "+" on a shared knob's boundary line (on every shared knob, all the time; the
    /// feature leaves out the knob being dragged). `ring` is its place in `addRings` (0 = 64 in
    /// from the rim), from `placed`.
    public struct AddBetween: Equatable, Sendable {
        public var knob: Int
        public var minute: Int
        public var ring: Int

        public init(knob: Int, minute: Int, ring: Int = 0) {
            self.knob = knob
            self.minute = minute
            self.ring = ring
        }
    }

    public static let radius: CGFloat = 340
    public static let hubRadius: CGFloat = 130
    /// Board G1: a "+" is a RoundButton 56 whose circle is drawn one part inset (6) inside its frame.
    public static let addSize: CGFloat = 56
    static var addDrawn: CGFloat { addSize - 2 * CrayonPart.inset }
    /// Spec "Add between two slices": a "+" centre sits on one of three rings, 64, 120 and 176 in
    /// from the rim (56 apart, more than a drawn circle, so "+" on two rings never touch).
    public static let addRings: [CGFloat] = [64, 120, 176]

    /// Spec "Add between two slices": two "+" on `ring` touch when their drawn circles (44) meet, at
    /// board units: under about 37 minutes apart on the outer ring (centres 276 from the middle),
    /// 46 on the middle one (220) and 62 on the inner one (164).
    public static func addButtonsOverlap(_ a: Int, _ b: Int, ring: Int = 0) -> Bool {
        let apart = abs(a - b) % 1440
        let minutes = Double(min(apart, 1440 - apart))
        let chord = 2 * (radius - addRings[ring]) * sin(minutes * 0.25 * .pi / 180 / 2)
        return chord < addDrawn
    }

    /// Spec "Sizing → Touch", rule 2: a drag that starts on a slice in the clock ring grabs the
    /// knob nearest by angle (`minute` and `knobs` in minutes of the day), up to half the angle to
    /// the next knob on that side. nil when there is no knob in reach.
    public static func grabbedKnob(at minute: Double, knobs: [Double]) -> Int? {
        func apart(_ a: Double, _ b: Double) -> Double {
            let d = abs(a - b).truncatingRemainder(dividingBy: 1440)
            return min(d, 1440 - d)
        }
        guard let nearest = knobs.indices.min(by: { apart(knobs[$0], minute) < apart(knobs[$1], minute) })
        else { return nil }
        // The next knob on the finger's side of the nearest one (itself, all the way round, when alone).
        let ahead = (minute - knobs[nearest] + 1440).truncatingRemainder(dividingBy: 1440) < 720
        let gap = knobs.indices.reduce(1440.0) { shortest, other in
            guard other != nearest else { return shortest }
            let forward = (knobs[other] - knobs[nearest] + 1440).truncatingRemainder(dividingBy: 1440)
            return min(shortest, ahead ? forward : 1440 - forward)
        }
        return apart(knobs[nearest], minute) <= gap / 2 ? nearest : nil
    }

    /// Spec "Add between two slices": each "+", in day order, takes the outermost ring where it
    /// touches no earlier "+"; with no ring free (four or more short slices in a row) it hides.
    public static func placed(_ buttons: [AddBetween]) -> [AddBetween] {
        var kept: [AddBetween] = []
        for var button in buttons.sorted(by: { $0.minute < $1.minute }) {
            let free = addRings.indices.first { ring in
                !kept.contains { $0.ring == ring && addButtonsOverlap($0.minute, button.minute, ring: ring) }
            }
            guard let free else { continue }
            button.ring = free
            kept.append(button)
        }
        return kept
    }

    private let sectors: [ClockSector]
    private let knobs: [Knob]
    private let dragging: Int?
    private let dragOrigin: Int?
    private let hub: Hub
    private let onKnobDrag: (Int, Int) -> Void
    private let onKnobEnd: (Int) -> Void
    private let addButtons: [AddBetween]
    private let onAddBetween: (Int) -> Void
    private let onSliceTap: (Int) -> Void
    private let onPlusTap: (Int) -> Void

    /// `sectors` marks the selected slice with `isCurrent`; `dragging` is the knob being dragged and
    /// `dragOrigin` its minute when the drag began (a dashed line stays there).
    public init(sectors: [ClockSector], knobs: [Knob], dragging: Int?, dragOrigin: Int?, hub: Hub,
                onKnobDrag: @escaping (Int, Int) -> Void, onKnobEnd: @escaping (Int) -> Void,
                onSliceTap: @escaping (Int) -> Void, onPlusTap: @escaping (Int) -> Void,
                addButtons: [AddBetween] = [], onAddBetween: @escaping (Int) -> Void = { _ in }) {
        // Sleep before and after midnight is one slice, as on the kid clock.
        self.sectors = PieClockLayout.drawable(sectors)
        self.knobs = knobs
        self.dragging = dragging
        self.dragOrigin = dragOrigin
        self.hub = hub
        self.onKnobDrag = onKnobDrag
        self.onKnobEnd = onKnobEnd
        self.addButtons = addButtons
        self.onAddBetween = onAddBetween
        self.onSliceTap = onSliceTap
        self.onPlusTap = onPlusTap
    }

    /// A drag in the clock ring: not yet decided, started off the ring (moves nothing), or holding
    /// a knob since the finger came down at `fingerStart` (the knob was at `knobStart`).
    private enum RingDrag: Equatable {
        case idle, ignored
        case grabbed(knob: Int, fingerStart: Double, knobStart: Double)
    }

    @State private var ringDrag = RingDrag.idle
    @Environment(\.sizing) private var sizing
    /// Board lengths on this screen (R 340, hub 130 on the 13"; the screen's scale elsewhere).
    private var k: CGFloat { sizing.s }
    private var r: CGFloat { EditClock.radius * k }
    private var hubR: CGFloat { EditClock.hubRadius * k }

    public var body: some View {
        ZStack {
            // Spec "Sizing → Touch": a tap on a slice picks it; a drag that starts on a slice in the
            // ring moves the nearest knob (rule 2). Knobs and "+" keep their own tap and drag.
            Circle().fill(CrayonColor.clockFace).frame(width: 2 * r, height: 2 * r)
                .onTapGesture(coordinateSpace: .local) { location in
                    guard let slice = PieClockLayout.sector(at: location, in: sectors, radius: r, hub: hubR)
                    else { return }
                    slice.style == .free ? onPlusTap(slice.start) : onSliceTap(slice.start)
                }
                .gesture(DragGesture(minimumDistance: 8, coordinateSpace: .named(Self.space))
                    .onChanged(ringDragged)
                    .onEnded { _ in
                        if case let .grabbed(knob, _, _) = ringDrag { onKnobEnd(knob) }
                        ringDrag = .idle
                    })
            ForEach(sectors, id: \.self) { sector in
                CrayonSurface(.sector(startDegrees: PieClockLayout.degrees(minute: sector.start),
                                      endDegrees: PieClockLayout.degrees(minute: sector.end)),
                              fill: sector.style.fill, marker: MarkerStyle(width: 2.5, roughness: 1.2, bowing: 1.4),
                              markerColor: CrayonColor.pictureOutline, seed: UInt32(3001 + sector.start))
                    .opacity(sector.isFaded ? 0.3 : 1)
                    .allowsHitTesting(false)
            }
            ForEach(sectors.filter(\.isCurrent), id: \.self) { sector in
                CrayonSurface(.sector(startDegrees: PieClockLayout.degrees(minute: sector.start),
                                      endDegrees: PieClockLayout.degrees(minute: sector.end)),
                              fill: nil, marker: MarkerStyle(width: 6, roughness: 1.2, bowing: 1.4),
                              markerColor: CrayonColor.pictureOutline, seed: UInt32(3001 + sector.start))
                    .allowsHitTesting(false)
            }
            // The face is a lit ground (spec "Night mapping"): its lines stay marker in dark mode.
            CrayonSurface(.circle, fill: nil, marker: MarkerStyle(width: 4.5, roughness: 1.2, bowing: 1.4),
                          markerColor: CrayonColor.pictureOutline, seed: 3000)
                .allowsHitTesting(false)
            ticksAndLabels
            pictures
            if let dragOrigin { originLine(dragOrigin) }
            hubDisc
            knobViews
            // Board G1: a RoundButton 56 on each shared knob's boundary line, its centre on its ring.
            ForEach(addButtons, id: \.knob) { button in
                RoundButton(glyph: .plus) { onAddBetween(button.knob) }
                    .size(Self.addSize)
                    .position(point(radius: r - Self.addRings[button.ring] * k, minute: Double(button.minute)))
            }
        }
        .frame(width: 2 * r, height: 2 * r)
        .coordinateSpace(.named(Self.space))
    }

    private static let space = "editClock"

    /// Rule 2 in the ring: the knob follows the finger by the angle it turned, from where it was.
    private func ringDragged(_ value: DragGesture.Value) {
        if ringDrag == .idle {
            let start = value.startLocation
            let distance = hypot(start.x - r, start.y - r)
            let minute = exactMinute(at: start)
            guard distance >= hubR, distance <= r,
                  let knob = Self.grabbedKnob(at: minute, knobs: knobs.map { Double($0.minute) }),
                  !knobs[knob].isLocked
            else {
                ringDrag = .ignored
                return
            }
            ringDrag = .grabbed(knob: knob, fingerStart: minute, knobStart: Double(knobs[knob].minute))
        }
        guard case let .grabbed(knob, fingerStart, knobStart) = ringDrag else { return }
        var turned = exactMinute(at: value.location) - fingerStart
        if turned > 720 { turned -= 1440 }
        if turned < -720 { turned += 1440 }
        onKnobDrag(knob, Int((knobStart + turned).rounded()))
    }

    /// The minute on the dial under `location`, unrounded, 0..<1440.
    private func exactMinute(at location: CGPoint) -> Double {
        var degrees = atan2(location.x - r, r - location.y) * 180 / .pi
        if degrees < 0 { degrees += 360 }
        return Double(degrees) * 4
    }

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
                    path.move(to: point(radius: r + 4 * k, minute: Double(hour * 60)))
                    path.addLine(to: point(radius: r + 16 * k, minute: Double(hour * 60)))
                }
                context.stroke(path, with: .color(CrayonColor.marker), style: StrokeStyle(lineWidth: 3 * k, lineCap: .round))
            }
            ForEach(0..<24, id: \.self) { hour in
                let major = hour % 6 == 0
                Text("\(hour % 12 == 0 ? 12 : hour % 12)")
                    .font(Font(FontRegistrar.font(size: sizing.size(of: major ? .body : .caption), weight: .semibold)))
                    .foregroundStyle(major ? CrayonColor.ink : CrayonColor.softText)
                    .position(point(radius: r + 40 * k, minute: Double(hour * 60)))
            }
        }
        .frame(width: 2 * r, height: 2 * r)
        .allowsHitTesting(false)
    }

    private var pictures: some View {
        ForEach(sectors, id: \.self) { sector in
            let middle = Double(sector.start + sector.end) / 2
            if sector.style == .free {
                // Spec G1 (#213): the same RoundButton 56 (drawn 44) as a boundary "+", at the
                // paper's middle angle halfway between hub and rim. A tap anywhere on the paper
                // still adds there (the sector's own tap).
                RoundButton(glyph: .plus) { onPlusTap(sector.start) }
                    .size(EditClock.addSize)
                    .position(point(radius: (hubR + r) / 2, minute: middle))
            } else if let name = sector.iconName, let slot = KitSlot(rawValue: name),
                      let picture = PieClockLayout.picture(minutes: sector.end - sector.start, radius: EditClock.radius,
                                                           hub: EditClock.hubRadius) {
                // Board units, then the screen's scale (as on the home clock).
                KitIcon(slot, size: picture.size * k)
                    .opacity(sector.isFaded ? 0.35 : 1)
                    .position(point(radius: picture.distance * k, minute: middle))
                    .allowsHitTesting(false)
            }
        }
    }

    private func originLine(_ minute: Int) -> some View {
        Path { path in
            path.move(to: point(radius: hubR, minute: Double(minute)))
            path.addLine(to: point(radius: r, minute: Double(minute)))
        }
        .stroke(CrayonColor.pictureMarker, style: StrokeStyle(lineWidth: 3 * k, lineCap: .round, dash: [8 * k, 8 * k]))
        .allowsHitTesting(false)
    }

    private var hubDisc: some View {
        VStack(spacing: sizing(Spacing.xxs)) {
            if let above = hub.above {
                Text(above).crayonType(.caption).foregroundStyle(CrayonColor.pictureSoftText)
            }
            if let time = hub.time {
                // At its own size, centred: shrinking to fit kept a full-width box and leaned the
                // time left of the hub's middle (iPad review, 2026-11-10). "12:30 pm" fits the hub.
                Text(time).crayonType(.title).foregroundStyle(hub.timeIsMuted ? CrayonColor.pictureSoftText : CrayonColor.pickBlue)
                    .fixedSize()
            }
            if let below = hub.below {
                Text(below).crayonType(.caption).foregroundStyle(CrayonColor.pictureSoftText)
            }
            if let title = hub.title {
                Text(title).crayonType(.head).foregroundStyle(CrayonColor.pictureInk).lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .multilineTextAlignment(.center)
        .frame(width: 2 * hubR - sizing(Spacing.m))
        .frame(width: 2 * hubR, height: 2 * hubR)
        .background(CrayonSurface(.circle, fill: CrayonStyle.pictureGround, markerColor: CrayonColor.pictureOutline, seed: 3003))
        .allowsHitTesting(false)
    }

    private var knobViews: some View {
        ForEach(Array(knobs.enumerated()), id: \.offset) { index, knob in
            ClockKnob(knob.isLocked ? .locked : (dragging == index ? .dragging : .idle))
                .position(point(radius: r, minute: Double(knob.minute)))
                .gesture(knob.isLocked ? nil : DragGesture(minimumDistance: 2, coordinateSpace: .named(Self.space))
                    .onChanged { onKnobDrag(index, minute(at: $0.location)) }
                    .onEnded { _ in onKnobEnd(index) })
        }
    }
}
