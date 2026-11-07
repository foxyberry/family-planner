import SwiftUI

/// The small colour dot next to a child's name (24–28 pt).
public struct KidDot: View {
    private let color: Color
    private let size: CGFloat

    public init(color: Color, size: CGFloat = 24) {
        self.color = color
        self.size = size
    }

    public var body: some View {
        Circle().fill(color).frame(width: size, height: size).accessibilityHidden(true)
    }
}
