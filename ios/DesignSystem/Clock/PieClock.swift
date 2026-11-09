import CrayonKit
import KitArt
import Strings
import SwiftUI

/// The 24-hour crayon pie clock (board A1). The view's frame is the disc (radius 372 × s); hour labels,
/// the moon and the sun sit outside it, so give the clock room around its frame.
public struct PieClock: View {
    /// The hub's text: the slot's name and "until 4:30 pm" (the weekday is on the right panel).
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
    private let look: KidLook
    private let motion: Motion
    private let plays: [Int: Int]
    private let rigScale: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The slot whose title the hub shows; it follows `motion.slotStart` (see `hubDisc`).
    @State private var shownSlotStart: Int?
    /// True when the clock moved forward to the new slot; false when it went back (time machine).
    @State private var hubForward = true
    @Environment(\.sizing) private var sizing

    /// Board 0g2 triggers, all from State: a new current slot (its picture hops, the hub text slides
    /// up), a new hour (the hand's disc pulses) and an idle wink (the sun or moon blinks).
    public struct Motion: Equatable, Sendable {
        public var slotStart: Int?
        public var hour: Int
        public var winks: Int

        public init(slotStart: Int? = nil, hour: Int = 0, winks: Int = 0) {
            self.slotStart = slotStart
            self.hour = hour
            self.winks = winks
        }
    }

    /// `now` is minutes after midnight; `nil` draws no hand (no schedule at all).
    /// `holdProgress` 0...1 draws the grown-up hold ring around the hub.
    /// `look` night (board A1n): a lit paper face under the slots, chalk ticks and hour numbers.
    /// `plays`: a play id per drawn sector start; when one changes, that slot's picture plays its rig
    /// (spec "Picture rigs") at `rigScale`.
    public init(sectors: [ClockSector], now: Int?, hub: Hub, holdProgress: Double = 0, look: KidLook = .day,
                motion: Motion = Motion(), plays: [Int: Int] = [:], rigScale: Double = KitRigs.shared.scale) {
        self.plays = plays
        self.rigScale = rigScale
        self.sectors = PieClockLayout.drawable(sectors)
        self.now = now
        self.hub = hub
        self.holdProgress = holdProgress
        self.look = look
        self.motion = motion
    }

    /// Spec "Sizing formulas": the clock and everything on it scale by s (R 372 s).
    private var k: CGFloat { sizing.s }
    private var r: CGFloat { PieClock.radius * k }
    private var hubR: CGFloat { Self.hubRadius * k }

    public var body: some View {
        ZStack {
            Circle().fill(look.clockFace).frame(width: 2 * r, height: 2 * r)
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
            if reduceMotion {
                // Reduce Motion: a tapped slot's outline thickens for 0.3 s instead of playing.
                ForEach(sectors.filter { plays[$0.start] != nil }, id: \.self) { sector in
                    CrayonSurface(.sector(startDegrees: PieClockLayout.degrees(minute: sector.start),
                                          endDegrees: PieClockLayout.degrees(minute: sector.end)),
                                  fill: nil, marker: MarkerStyle(width: 9, roughness: 1.2, bowing: 1.4),
                                  seed: UInt32(3001 + sector.start))
                        .keyframeAnimator(initialValue: 0.0, trigger: plays[sector.start] ?? 0) { view, value in
                            view.opacity(value)
                        } keyframes: { _ in
                            LinearKeyframe(1.0, duration: 0.05)
                            LinearKeyframe(1.0, duration: 0.2)
                            LinearKeyframe(0.0, duration: 0.05)
                        }
                }
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
                    .stroke(CrayonColor.marker, style: StrokeStyle(lineWidth: 8 * k, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 320 * k, height: 320 * k)
            }
        }
        .frame(width: 2 * r, height: 2 * r)
    }

    /// A point `radius` from the centre at `degrees` clockwise from 12 o'clock.
    private func point(radius: CGFloat, degrees: Double) -> CGPoint {
        let a = degrees * .pi / 180
        return CGPoint(x: r + radius * CGFloat(sin(a)), y: r - radius * CGFloat(cos(a)))
    }

    /// The 24 hour ticks just outside the ring (378–392). A Path, not a Canvas: a Canvas clips to its
    /// 2r frame and cut the 12 and 6 ticks off (drift sweep 2026-11-09).
    private var ticks: some View {
        Path { path in
            for hour in 0..<24 {
                path.move(to: point(radius: 378 * k, degrees: Double(hour) * 15))
                path.addLine(to: point(radius: 392 * k, degrees: Double(hour) * 15))
            }
        }
        .stroke(look.tick, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .frame(width: 2 * r, height: 2 * r)
        .allowsHitTesting(false)
    }

    private var labels: some View {
        ForEach(0..<24, id: \.self) { hour in
            let major = hour % 6 == 0
            Text("\(hour % 12 == 0 ? 12 : hour % 12)")
                .font(Font(FontRegistrar.font(size: major ? sizing.fluid(30, 24) : 24, weight: .semibold)))
                .foregroundStyle(major ? look.majorLabel : look.minorLabel)
                .position(point(radius: 412 * k, degrees: Double(hour) * 15))
        }
        .overlay {
            // Boards A1/E3: the moon (40) beside the top 12, the sun (44) beside the bottom 12 (layout
            // clock.slotPicture.1 and .9).
            KitIcon(.actSleep, size: 40 * k).blink(look == .night ? motion.winks : nil, reduceMotion: reduceMotion)
                .position(x: r + 50 * k, y: r - 422 * k)
            KitIcon(.sun, size: 44 * k).blink(look == .day ? motion.winks : nil, reduceMotion: reduceMotion)
                .position(x: r + 52 * k, y: r + 420 * k)
        }
        .allowsHitTesting(false)
    }

    private var pictures: some View {
        ForEach(sectors, id: \.self) { sector in
            let middle = PieClockLayout.degrees(minute: (sector.start + sector.end) / 2)
            if let name = sector.iconName, let slot = KitSlot(rawValue: name),
               let picture = PieClockLayout.picture(minutes: sector.end - sector.start, radius: PieClock.radius,
                                                    hub: Self.hubRadius) {
                RiggedKitIcon(slot, size: picture.size * k, playID: reduceMotion ? 0 : plays[sector.start] ?? 0,
                              scale: rigScale)
                    .hop(sector.isCurrent && !reduceMotion ? motion.slotStart : nil)
                    .position(point(radius: picture.distance * k, degrees: middle))
            }
            if sector.showsStar {
                KitIcon(.star, size: 40 * k).position(point(radius: (Self.hubRadius + 36) * k, degrees: middle))
            }
        }
        .allowsHitTesting(false)
    }

    private func hand(at minute: Int) -> some View {
        let degrees = PieClockLayout.degrees(minute: minute)
        return ZStack {
            Path { path in
                path.move(to: point(radius: 154 * k, degrees: degrees))
                path.addLine(to: point(radius: 312 * k, degrees: degrees))
            }
            .stroke(CrayonColor.handRed, style: StrokeStyle(lineWidth: 9 * k, lineCap: .round))
            CrayonSurface(.circle, fill: CrayonFill(color: CrayonColor.handRed, hachure: HachureStyle(degrees: -40)),
                          seed: 3002)
                .frame(width: 48 * k, height: 48 * k)
                .keyframeAnimator(initialValue: 1.0, trigger: reduceMotion ? 0 : motion.hour) { disc, scale in
                    disc.scaleEffect(scale)
                } keyframes: { _ in
                    CubicKeyframe(1.3, duration: 0.25)
                    CubicKeyframe(1.0, duration: 0.35)
                }
                .position(point(radius: 336 * k, degrees: degrees))
        }
        .frame(width: 2 * r, height: 2 * r)
        .allowsHitTesting(false)
    }

    /// Board A1 hub text (spec "Hub text", 2026-11-08): the title and "until" only, each on its own
    /// baseline on the 1032 board where the hub's centre is y 528:
    /// - one title line: title 48 at 540, "until" 590;
    /// - two title lines (head 36, 38 apart): 512 and 550, "until" 594.
    /// Lines are placed by baseline, not stacked, because Playpen Sans has tall built-in line gaps.
    /// Forward when the new slot is less than 12 hours ahead around the clock (so the evening to
    /// the first slot after midnight is forward); otherwise time went back.
    public static func isForward(from old: Int, to new: Int) -> Bool {
        ((new - old) % 1440 + 1440) % 1440 < 720
    }

    private var hubDisc: some View {
        let title = hub.title.map { Self.hubTitleLines($0, sizing: sizing) }
        let isTwoLines = (title?.lines.count ?? 1) > 1
        let titleBaselines: [CGFloat] = isTwoLines ? [512, 550] : [540]
        let untilBaseline: CGFloat = isTwoLines ? 594 : 590
        return ZStack {
            if let title {
                ZStack {
                    ForEach(Array(zip(title.lines, titleBaselines)), id: \.1) { line, baseline in
                        hubLine(line, size: sizing.size(of: title.isTitle ? .title : .head),
                                weight: .bold, color: CrayonColor.ink, baseline: baseline)
                    }
                }
                .id(reduceMotion ? nil : shownSlotStart)
                // User, 2026-11-09: a new slot swipes in from the left inside the hub (from the
                // right when time goes back), pushing the old title out the other side.
                .transition(.asymmetric(insertion: .move(edge: hubForward ? .leading : .trailing),
                                        removal: .move(edge: hubForward ? .trailing : .leading)))
            }
            if let subtitle = hub.subtitle {
                hubLine(subtitle, size: sizing.size(of: .body), weight: .medium, color: CrayonColor.softText,
                        baseline: untilBaseline)
            }
        }
        // Board 0g2 "new slot": the title rises only when the slot changes while the clock is on
        // screen, never when the first slot arrives at launch (user, 2026-11-09).
        .onChange(of: motion.slotStart, initial: true) { old, new in
            if old == nil || old == new || reduceMotion {
                var quiet = Transaction()
                quiet.disablesAnimations = true
                withTransaction(quiet) { shownSlotStart = new }
            } else {
                hubForward = PieClock.isForward(from: old ?? 0, to: new ?? 0)
                withAnimation(.easeInOut(duration: 0.45)) { shownSlotStart = new }
            }
        }
        .frame(width: 2 * hubR, height: 2 * hubR)
        // The swipe stays inside the hub disc.
        .clipShape(Circle())
        .crayonBackground(.circle, fill: look.surface, seed: 3003)
        .accessibilityHidden(true)
    }

    /// One centred line whose baseline sits at `baseline` on the board (hub centre y 528).
    private func hubLine(_ text: String, size: CGFloat, weight: UIFont.Weight, color: Color,
                         baseline: CGFloat) -> some View {
        let font = FontRegistrar.font(size: size, weight: weight)
        let top = hubR + (baseline - 528) * k - font.ascender
        return Text(text).font(Font(font)).foregroundStyle(color)
            .lineLimit(1).truncationMode(.tail)
            .frame(maxWidth: Self.headWidth * k)
            .position(x: hubR, y: top + font.lineHeight / 2)
    }

    /// The start of the drawn slot under a tap at `location` in the clock's own frame (drawn at
    /// scale `s`), if any.
    public static func slotStart(at location: CGPoint, in sectors: [ClockSector], scale s: CGFloat = 1) -> Int? {
        PieClockLayout.sector(at: CGPoint(x: location.x / s, y: location.y / s), in: sectors, radius: radius,
                              hub: hubRadius)?.start
    }

    static let titleWidth: CGFloat = 260
    static let headWidth: CGFloat = 284

    /// The hub title as drawn: title 48 on one line if it fits 260; else head 36 broken at words into
    /// at most two lines within 284 (the second line ends with "…" when the rest is too long).
    public nonisolated static func hubTitleLines(_ title: String, sizing: Sizing = .thirteenInch)
        -> (lines: [String], isTitle: Bool) {
        let titleSize = sizing.size(of: .title), headSize = sizing.size(of: .head)
        let titleWidth = Self.titleWidth * sizing.s, headWidth = Self.headWidth * sizing.s
        func width(_ text: String, _ size: CGFloat) -> CGFloat {
            let font = FontRegistrar.font(size: size, weight: .bold)
            return ceil((text as NSString).size(withAttributes: [.font: font]).width)
        }
        if width(title, titleSize) <= titleWidth { return ([title], true) }
        if width(title, headSize) <= headWidth { return ([title], false) }
        let words = title.split(separator: " ").map(String.init)
        var first = words.first ?? title
        var used = 1
        while used < words.count, width(first + " " + words[used], headSize) <= headWidth {
            first += " " + words[used]
            used += 1
        }
        let rest = words.dropFirst(used).joined(separator: " ")
        return (rest.isEmpty ? [first] : [first, rest], false)
    }
}

extension View {
    /// Board 0g2 new slot: hop 1 → 1.15 → 1 in 0.4 s each time `trigger` changes (`nil`: still).
    func hop(_ trigger: Int?) -> some View {
        keyframeAnimator(initialValue: 1.0, trigger: trigger) { view, scale in
            view.scaleEffect(scale)
        } keyframes: { _ in
            CubicKeyframe(1.15, duration: 0.2)
            CubicKeyframe(1.0, duration: 0.2)
        }
    }

    /// Board 0g2 idle wink: a 0.3 s blink each time `trigger` changes (`nil`, Reduce Motion: still).
    func blink(_ trigger: Int?, reduceMotion: Bool) -> some View {
        keyframeAnimator(initialValue: 1.0, trigger: reduceMotion ? nil : trigger) { view, height in
            view.scaleEffect(x: 1, y: height)
        } keyframes: { _ in
            CubicKeyframe(0.15, duration: 0.15)
            CubicKeyframe(1.0, duration: 0.15)
        }
    }
}
