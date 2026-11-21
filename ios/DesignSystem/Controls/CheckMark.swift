import CrayonKit
import SwiftUI

/// Done state of a step: a blue crayon circle with a white tick, or an empty marker circle.
public struct CheckMark: View {
    private let isDone: Bool
    private let size: CGFloat
    @Environment(\.sizing) private var sizing

    /// `size`: the board diameter (× s on screen).
    public init(isDone: Bool, size: CGFloat = 56) {
        self.isDone = isDone
        self.size = size
    }

    public var body: some View {
        ZStack {
            CrayonSurface(.circle, fill: isDone ? CrayonStyle.blueCrayon : nil, seed: CrayonStyle.Seed.checkMark)
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: sizing(size) * 0.45, weight: .heavy))
                    .foregroundStyle(CrayonColor.tick)
            }
        }
        .frame(width: sizing(size), height: sizing(size))
    }
}
