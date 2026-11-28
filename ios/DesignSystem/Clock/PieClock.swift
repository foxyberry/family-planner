import CrayonKit
import KitArt
import Strings
import SwiftUI

/// The 24-hour crayon pie clock (board A1). The view's frame is the disc (radius 372 × s); hour labels,
/// the moon and the sun sit outside it, so give the clock room around its frame.
public struct PieClock: View {
    /// Spec A1 "Hub" (layout v81): whose clock, which day, what time. The picked kid's face 48 (top
    /// 436), the weekday (28 bold, baseline 524) and the time ("6:52" 48 bold + "am" 24 soft, baseline
    /// 578). On a public holiday the weekday is red, the holiday's name sits under the time and the
    /// face is left out: weekday 494, time 548, name 586.
    public struct Hub: Equatable, Sendable {
        public var face: KidFace.Badge?
        public var weekday: String
        public var time: String
        public var period: String
        /// The public holiday's name; nil on any other day.
        public var holiday: String?

        public init(face: KidFace.Badge?, weekday: String, time: String, period: String, holiday: String?) {
            self.face = face
            self.weekday = weekday
            self.time = time
            self.period = period
            self.holiday = holiday
        }
    }

    public static let radius: CGFloat = 372
    /// Layout v81: the hub is r 142, the same share of the disc as G1's (130 / 340); it holds the face,
    /// the weekday and the time. Slot pictures start at r 150, the hand at r 144.
    static let hubRadius: CGFloat = 142

    private let sectors: [ClockSector]
    private let now: Int?
    private let hub: Hub
    private let holdProgress: Double
    private let look: KidLook
    private let motion: Motion
    private let plays: [Int: Int]
    private let rigScale: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sizing) private var sizing

    /// Board 0g2 triggers, all from State: a new current slot (its picture hops), a new hour (the hand's disc pulses) and an idle wink (the sun or moon blinks).
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

    /// Spec "Sizing: one scale, no floors": the clock and everything on it scale by s (R 372 s).
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
                        .keyframeAnimator(initialValue: 0.0, trigger: plays[sector.start, default: 0]) { view, value in
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
                    .frame(width: 2 * (Self.hubRadius + 12) * k, height: 2 * (Self.hubRadius + 12) * k)
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
        .stroke(look.tick, style: StrokeStyle(lineWidth: 3 * k, lineCap: .round))
        .frame(width: 2 * r, height: 2 * r)
        .allowsHitTesting(false)
    }

    private var labels: some View {
        ForEach(0..<24, id: \.self) { hour in
            let major = hour % 6 == 0
            Text("\(hour % 12 == 0 ? 12 : hour % 12)")
                .font(Font(FontRegistrar.font(size: sizing.size(of: major ? .body : .caption), weight: .semibold)))
                .foregroundStyle(major ? look.majorLabel : look.minorLabel)
                .position(point(radius: 412 * k, degrees: Double(hour) * 15))
        }
        .overlay {
            // Layout v30: the moon (40) centred above the top 12 at (428, 48), the sun (44) centred
            // below the bottom 12 at (426, 964); the disc's centre is (448, 528).
            KitIcon(.actSleep, size: 40 * k).blink(look == .night ? motion.winks : nil, reduceMotion: reduceMotion)
                .position(x: r, y: r - 460 * k)
            KitIcon(.sun, size: 44 * k).blink(look == .day ? motion.winks : nil, reduceMotion: reduceMotion)
                .position(x: r, y: r + 458 * k)
        }
        .allowsHitTesting(false)
    }

    private var pictures: some View {
        ForEach(sectors, id: \.self) { sector in
            let middle = PieClockLayout.degrees(minute: (sector.start + sector.end) / 2)
            if let name = sector.iconName, let slot = KitSlot(rawValue: name),
               let picture = PieClockLayout.picture(minutes: sector.end - sector.start, radius: PieClock.radius,
                                                    hub: Self.hubRadius) {
                RiggedKitIcon(slot, size: picture.size * k, playID: reduceMotion ? 0 : plays[sector.start, default: 0],
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
                path.move(to: point(radius: (Self.hubRadius + 2) * k, degrees: degrees))
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

    /// The hub is a light surface by day and night (white, moon paper), so its words stay dark.
    private var hubDisc: some View {
        let holiday = hub.holiday != nil
        return ZStack {
            if let face = hub.face, !holiday {
                KidFace(face, size: 48 * k).position(x: hubR, y: hubR + (436 + 24 - 528) * k)
            }
            hubLine(Text(hub.weekday).font(Font(FontRegistrar.font(size: 28 * k, weight: .bold)))
                        .foregroundStyle(holiday ? look.late : CrayonColor.ink),
                    size: 28, baseline: holiday ? 494 : 524)
            hubLine(HStack(alignment: .firstTextBaseline, spacing: 6 * k) {
                        Text(hub.time).font(Font(FontRegistrar.font(size: 48 * k, weight: .bold))).foregroundStyle(CrayonColor.ink)
                        Text(hub.period).font(Font(FontRegistrar.font(size: 24 * k, weight: .bold)))
                            .foregroundStyle(CrayonColor.softText)
                    },
                    size: 48, baseline: holiday ? 548 : 578)
            if let name = hub.holiday {
                hubLine(Text(name).font(Font(FontRegistrar.font(size: 24 * k, weight: .medium)))
                            .foregroundStyle(CrayonColor.softText),
                        size: 24, baseline: 586, width: Self.lineWidth)
            }
        }
        .frame(width: 2 * hubR, height: 2 * hubR)
        .clipShape(Circle())
        .crayonBackground(.circle, fill: look.surface, seed: 3003)
    }

    /// One centred line whose baseline sits at `baseline` on the board (hub centre y 528); `size` is
    /// the line's largest type (board), which sets its ascender. A long line ends with "…".
    /// `width`: the line's room (board); the weekday and the time keep their full width.
    private func hubLine(_ text: some View, size: CGFloat, baseline: CGFloat, width: CGFloat = 2 * hubRadius) -> some View {
        let font = FontRegistrar.font(size: size * k, weight: .bold)
        let top = hubR + (baseline - 528) * k - font.ascender
        return text.lineLimit(1).truncationMode(.tail).monospacedDigit()
            .frame(maxWidth: width * k)
            .position(x: hubR, y: top + font.lineHeight / 2)
    }

    /// Spec A1 "Hub": a name that does not fit the hub (about 250 wide at its line) ends with "…".
    static let lineWidth: CGFloat = 250

    /// The start of the drawn slot under a tap at `location` in the clock's own frame (drawn at
    /// scale `s`), if any.
    public static func slotStart(at location: CGPoint, in sectors: [ClockSector], scale s: CGFloat = 1) -> Int? {
        PieClockLayout.sector(at: CGPoint(x: location.x / s, y: location.y / s), in: sectors, radius: radius,
                              hub: hubRadius)?.start
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
