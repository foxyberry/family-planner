import KitArt
import SwiftUI

/// A kit picture that plays its rig once each time `playID` changes (spec "Picture rigs", boards
/// 0g3 / 0g3b): the picture's runs stacked in draw order, each moving part turning or moving about
/// its origin. A slot without a rig, or with a private override picture, hops as a whole.
/// At rest it looks exactly like `KitIcon`.
public struct RiggedKitIcon: View {
    private let slot: KitSlot
    private let size: CGFloat
    private let playID: Int
    private let scale: Double

    public init(_ slot: KitSlot, size: CGFloat, playID: Int, scale: Double = KitRigs.shared.scale) {
        self.slot = slot
        self.size = size
        self.playID = playID
        self.scale = scale
    }

    public var body: some View {
        let rigs = KitRigs.shared
        let usesRuns = BundledKitArt().source(for: slot) == .public
        if usesRuns, let rig = rigs.rig(for: slot), !rig.runs.isEmpty {
            ZStack {
                ForEach(Array(rig.runs.enumerated()), id: \.offset) { _, run in
                    let image = BundledKitArt.runImage(named: run.image).resizable().scaledToFit()
                    if let name = run.part, let part = rig.parts[name] {
                        moving(image, part: part)
                    } else {
                        image
                    }
                }
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
        } else if let whole = rigs.fallback.parts["all"] {
            moving(KitIcon(slot, size: size), part: whole)
                .frame(width: size, height: size)
        }
    }

    /// One part, animated through `RigMotion` over the play; the units are the kit's 240 box.
    private func moving(_ content: some View, part: KitRig.Part) -> some View {
        let unit = size / 240
        let anchor = UnitPoint(x: part.origin.x / 240, y: part.origin.y / 240)
        return content
            .keyframeAnimator(initialValue: 0.0, trigger: playID) { view, time in
                let pose = RigMotion.pose(part.moves, at: time, scale: scale)
                view
                    .scaleEffect(x: pose.scale, y: pose.scale * pose.scaleY, anchor: anchor)
                    .rotationEffect(.degrees(pose.rotation), anchor: anchor)
                    .offset(x: pose.offset.width * unit, y: pose.offset.height * unit)
                    .opacity(pose.opacity)
            } keyframes: { _ in
                LinearKeyframe(RigMotion.duration, duration: RigMotion.duration)
            }
    }
}

public extension EnvironmentValues {
    /// How big rig moves play (spec "Picture rigs"): the kit data's scale, or the debug menu's
    /// "Rig scale" slider in debug builds, set once at the app root.
    @Entry var rigScale: Double = KitRigs.shared.scale
}
