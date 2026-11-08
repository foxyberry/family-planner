import KitArt
import SwiftUI

/// The slide's knob (spec Motion table, "Slide to go"): while the finger holds it the bus rocks and
/// its wheels turn with the finger, backwards when dragged back (`roll` is the distance travelled,
/// in points); the star twinkles. Reduce Motion: still.
public struct RollingKitIcon: View {
    private let slot: KitSlot
    private let size: CGFloat
    private let roll: CGFloat
    private let isHeld: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(_ slot: KitSlot, size: CGFloat, roll: CGFloat, isHeld: Bool) {
        self.slot = slot
        self.size = size
        self.roll = roll
        self.isHeld = isHeld
    }

    public var body: some View {
        picture
            .frame(width: size, height: size)
            .phaseAnimator(reduceMotion || !isHeld ? [0.0] : [0.0, 1.0, 0.0, -1.0]) { view, phase in
                view.rotationEffect(.degrees(slot == .star ? 0 : 2 * phase), anchor: .bottom)
                    .scaleEffect(slot == .star ? 1 + 0.12 * abs(phase) : 1)
            } animation: { _ in .easeInOut(duration: 0.2) }
            .accessibilityHidden(true)
    }

    /// The wheels turn one revolution per wheel circumference travelled (a wheel is about 44 of 240).
    private var wheelDegrees: Double {
        guard !reduceMotion else { return 0 }
        let circumference = Double.pi * Double(size) * 44 / 240
        return Double(roll) / circumference * 360
    }

    @ViewBuilder private var picture: some View {
        if let rig = DrivingKitIcon.wheeledRig(for: slot) {
            ZStack {
                ForEach(Array(rig.runs.enumerated()), id: \.offset) { _, run in
                    let image = BundledKitArt.runImage(named: run.image).resizable().scaledToFit()
                    if let name = run.part, DrivingKitIcon.isWheel(name), let part = rig.parts[name] {
                        image.rotationEffect(.degrees(wheelDegrees),
                                             anchor: UnitPoint(x: part.origin.x / 240, y: part.origin.y / 240))
                    } else {
                        image
                    }
                }
            }
        } else {
            KitIcon(slot, size: size)
        }
    }
}
