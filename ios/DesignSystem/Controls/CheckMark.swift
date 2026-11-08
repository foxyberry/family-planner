import CrayonKit
import Strings
import SwiftUI

/// Done state of a step: a blue crayon circle with a white tick, or an empty marker circle.
public struct CheckMark: View {
    private let isDone: Bool
    private let size: CGFloat

    public init(isDone: Bool, size: CGFloat = 56) {
        self.isDone = isDone
        self.size = size
    }

    public var body: some View {
        ZStack {
            CrayonSurface(.circle, fill: isDone ? CrayonStyle.blueCrayon : nil, seed: CrayonStyle.Seed.checkMark)
            if isDone {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.45, weight: .heavy))
                    .foregroundStyle(CrayonColor.card)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(isDone ? L10n.tr("check.done") : L10n.tr("check.not_done"))
    }
}
