import CrayonKit
import SwiftUI

/// First-run setup's progress (boards S1–S4): four 28 dots 8 apart, filled up to the current step.
public struct StepDots: View {
    private let current: Int
    private let total: Int
    private let label: String

    /// `current` is 1-based. `label`: what VoiceOver reads ("Step 1 of 4"), from the caller.
    public init(current: Int, total: Int = 4, label: String) {
        self.current = current
        self.total = total
        self.label = label
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(1...max(total, 1), id: \.self) { step in
                // A small circle needs a calm line: the standard roughness draws it as a polygon.
                CrayonSurface(.circle, fill: step <= current ? CrayonStyle.blueCrayon : nil,
                              marker: MarkerStyle(width: 3, roughness: 0.4, bowing: 0.4),
                              markerColor: step <= current ? CrayonColor.pickBlue : CrayonColor.marker,
                              seed: CrayonStyle.Seed.stepDots + UInt32(step))
                    .frame(width: 28, height: 28)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}
