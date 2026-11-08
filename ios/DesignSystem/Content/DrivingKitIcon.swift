import KitArt
import SwiftUI

/// A vehicle on its way (backlog N1a, the A2 map; way strip "It rocks as on A2"): the whole
/// picture rocks on a 0.9 s loop (1°, 2 pt). A rigged vehicle also plays its tap rig over and
/// over (the bus body bobs, as on board 0g3, at the rig scale) and its wheel runs turn all the
/// time about their centres (360° every 0.9 s, linear). Vehicles without a rig (car, taxi, shoe)
/// only rock. Reduce Motion: still. At rest it looks exactly like `KitIcon`.
public struct DrivingKitIcon: View {
    private let slot: KitSlot
    private let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.rigScale) private var rigScale

    public init(_ slot: KitSlot, size: CGFloat) {
        self.slot = slot
        self.size = size
    }

    /// One rock loop and one wheel turn.
    public static let loop: Double = 0.9

    public var body: some View {
        picture
            .frame(width: size, height: size)
            // Upright first (so it rests like KitIcon), then tilt 1° each way, lifting 2 pt.
            .phaseAnimator(reduceMotion ? [0.0] : [0.0, 1.0, 0.0, -1.0]) { view, phase in
                view
                    .rotationEffect(.degrees(phase), anchor: .bottom)
                    .offset(y: -2 * abs(phase))
            } animation: { _ in .easeInOut(duration: Self.loop / 4) }
            .accessibilityHidden(true)
    }

    @ViewBuilder private var picture: some View {
        let usesRuns = BundledKitArt().source(for: slot) == .public
        if usesRuns, let rig = KitRigs.shared.rig(for: slot), rig.parts.keys.contains(where: Self.isWheel) {
            ZStack {
                ForEach(Array(rig.runs.enumerated()), id: \.offset) { _, run in
                    let image = BundledKitArt.runImage(named: run.image).resizable().scaledToFit()
                    if let name = run.part, let part = rig.parts[name] {
                        if Self.isWheel(name) {
                            TurningWheel(image: image, origin: part.origin, isTurning: !reduceMotion)
                        } else {
                            LoopingPart(image: image, part: part, size: size, scale: rigScale, isPlaying: !reduceMotion)
                        }
                    } else {
                        image
                    }
                }
            }
        } else {
            KitIcon(slot, size: size)
        }
    }

    /// Wheel parts are tagged "back wheel" / "front wheel" in kit.js.
    static func isWheel(_ part: String) -> Bool { part.hasSuffix("wheel") }
}

/// A rig part (the bus body) playing its rig moves on a loop, one play after another.
private struct LoopingPart<Picture: View>: View {
    let image: Picture
    let part: KitRig.Part
    let size: CGFloat
    let scale: Double
    let isPlaying: Bool

    var body: some View {
        let unit = size / 240
        let anchor = UnitPoint(x: part.origin.x / 240, y: part.origin.y / 240)
        image.keyframeAnimator(initialValue: 0.0, repeating: isPlaying) { view, time in
            let pose = RigMotion.pose(part.moves, at: time, scale: scale)
            view
                .scaleEffect(x: pose.scale, y: pose.scale * pose.scaleY, anchor: anchor)
                .rotationEffect(.degrees(pose.rotation), anchor: anchor)
                .offset(x: pose.offset.width * unit, y: pose.offset.height * unit)
        } keyframes: { _ in
            LinearKeyframe(RigMotion.duration, duration: RigMotion.duration)
        }
    }
}

/// One wheel run turning about its centre (the part's origin in the kit's 240 box).
private struct TurningWheel<Picture: View>: View {
    let image: Picture
    let origin: CGPoint
    let isTurning: Bool
    @State private var turned = false

    var body: some View {
        image
            .rotationEffect(.degrees(turned ? 360 : 0), anchor: UnitPoint(x: origin.x / 240, y: origin.y / 240))
            .animation(isTurning ? .linear(duration: DrivingKitIcon.loop).repeatForever(autoreverses: false) : nil,
                       value: turned)
            .onAppear { if isTurning { turned = true } }
    }
}
