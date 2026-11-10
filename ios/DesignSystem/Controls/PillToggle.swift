import CrayonKit
import SwiftUI

/// A pill that toggles (boards C2, S3: the bus numbers), 180 × 72: sky blue and bold when on, paper
/// when off. Several can be on at once; a row of them wraps (`PillToggle.columns`).
public struct PillToggle: View {
    public static let size = CGSize(width: 180, height: 72)
    /// Grid columns for a row of pills in the 610 control column (three across, gap 12).
    public static let columns = Array(repeating: GridItem(.fixed(size.width), spacing: Spacing.sm), count: 3)

    private let title: String
    private let isOn: Bool
    private let action: () -> Void

    public init(_ title: String, isOn: Bool, action: @escaping () -> Void) {
        self.title = title
        self.isOn = isOn
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .crayonType(.head, bold: isOn)
                .foregroundStyle(isOn ? CrayonColor.pictureInk : CrayonColor.ink)
                .lineLimit(1)
                .frame(width: Self.size.width, height: Self.size.height)
                .partBackground(.capsule, fill: isOn ? CrayonStyle.skyPill : CrayonStyle.paper,
                                  seed: CrayonStyle.Seed.tabs + 50)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
