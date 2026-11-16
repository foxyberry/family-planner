import CrayonKit
import SwiftUI

/// A pill that toggles (boards C2, S3: the bus numbers), 180 × 72: sky blue and bold when on, paper
/// when off. Several can be on at once; a row of them wraps (`PillToggle.columns`).
public struct PillToggle: View {
    @Environment(\.sizing) private var sizing
    public static let size = CGSize(width: 180, height: 72)
    /// Grid columns for a row of pills in the 610 control column (three across, gap 12).
    public static let columns = Array(repeating: GridItem(.fixed(size.width), spacing: Spacing.sm), count: 3)
    /// As many 180 columns as fit `width` (3 on the 13"; fewer where a narrower card would overflow).
    public static func columns(fitting width: CGFloat) -> [GridItem] {
        let count = max(1, min(3, Int((width + Spacing.sm) / (size.width + Spacing.sm))))
        return Array(repeating: GridItem(.fixed(size.width), spacing: Spacing.sm), count: count)
    }

    private let title: String
    private let isOn: Bool
    private let tag: String?
    private let action: () -> Void

    /// `tag`: C2's "1st" / "2nd" after the number (spec "C2 rows"). A tagged pill that is off is the
    /// 2nd choice: the off look at 70 % with its tag.
    public init(_ title: String, isOn: Bool, tag: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.isOn = isOn
        self.tag = tag
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                Text(title)
                    .crayonType(.head, bold: isOn)
                    .foregroundStyle(isOn ? CrayonColor.pictureInk : CrayonColor.ink)
                    .lineLimit(1)
                if let tag {
                    Text(tag)
                        .crayonType(.caption, bold: true)
                        .foregroundStyle(isOn ? CrayonColor.pictureInk : CrayonColor.softText)
                        .padding(.horizontal, Spacing.xs)
                        .partBackground(.roundedRect(cornerRadius: 10), fill: CrayonStyle.paper,
                                        seed: CrayonStyle.Seed.tabs + 51)
                }
            }
            // Spec "Part floors": 72 × s tall, never under 56; the width stays 180.
            .frame(width: Self.size.width).frame(minHeight: sizing.tabHeight(Self.size.height))
            .partBackground(.capsule, fill: isOn ? CrayonStyle.skyPill : CrayonStyle.paper,
                            seed: CrayonStyle.Seed.tabs + 50)
            .opacity(!isOn && tag != nil ? 0.7 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn || tag != nil ? .isSelected : [])
    }
}

/// A wrapping grid of `PillToggle`s in a form's control column: 3 columns of 180 on the 13", fewer
/// when the column cannot hold them.
public struct PillToggleGrid<Content: View>: View {
    private let controlWidth: CGFloat
    private let content: Content

    public init(controlWidth: CGFloat, @ViewBuilder content: () -> Content) {
        self.controlWidth = controlWidth
        self.content = content()
    }

    public var body: some View {
        LazyVGrid(columns: PillToggle.columns(fitting: controlWidth), alignment: .leading,
                  spacing: Spacing.sm) { content }
    }
}
