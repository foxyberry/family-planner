import KitArt
import SwiftUI

/// The kid's day/night switch (board 0g): a 160 × 96 sky pill. A tap swaps the look; the plan
/// takes over again at its next change. While it animates the pill shows the sunset (`skyDusk`)
/// for the first 300 ms. Reduce Motion: the pill just swaps.
public struct SkySwitch: View {
    public static let size = CGSize(width: 160, height: 96)

    private let look: KidLook
    private let isAnimating: Bool
    private let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// On the screen's scale, like the pencil across from it (160 × 96 on the 13").
    @Environment(\.sizing) private var sizing
    /// 160 × 96, × s.
    private var width: CGFloat { sizing.kidCornerControl * Self.size.width / Self.size.height }
    @State private var showsDusk = false

    public init(look: KidLook, isAnimating: Bool, action: @escaping () -> Void) {
        self.look = look
        self.isAnimating = isAnimating
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            KitIcon(showsDusk ? .skyDusk : (look == .day ? .skyDay : .skyNight), size: width)
                .frame(width: width, height: width * Self.size.height / Self.size.width)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isAnimating) { _, new in new }
        .sensoryFeedback(.success, trigger: isAnimating) { old, new in old && !new }
        .task(id: isAnimating) {
            guard isAnimating, !reduceMotion else { return }
            showsDusk = true
            try? await Task.sleep(for: .milliseconds(300))
            showsDusk = false
        }
    }
}
