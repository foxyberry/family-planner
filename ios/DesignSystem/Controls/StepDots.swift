import CrayonKit
import Strings
import SwiftUI

/// First-run setup's progress (boards S1–S4): four 28 dots 8 apart, filled up to the current step.
public struct StepDots: View {
    private let current: Int
    private let total: Int

    /// `current` is 1-based.
    public init(current: Int, total: Int = 4) {
        self.current = current
        self.total = total
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(1...max(total, 1), id: \.self) { step in
                CrayonSurface(.circle, fill: step <= current ? CrayonStyle.blueCrayon : nil, marker: .thin,
                              markerColor: step <= current ? CrayonColor.pickBlue : CrayonColor.marker,
                              seed: CrayonStyle.Seed.stepDots + UInt32(step))
                    .frame(width: 28, height: 28)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.tr("setup.step", current, total))
    }
}
