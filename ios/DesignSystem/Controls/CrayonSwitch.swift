import CrayonKit
import SwiftUI

/// Spec "S4 · Almost done" `CrayonSwitch`: a 96 × 52 track (sky `tab-on` when on, paper `tab-off`
/// when off) with a 44 paper knob at x 48 on / x 4 off, the check picture 28 inside it when on.
/// The knob slides in 0.2 s. Its row (`SettingRow`) is the touch area.
public struct CrayonSwitch: View {
    public static let size = CGSize(width: 96, height: 52)
    private static let knob: CGFloat = 44

    private let isOn: Bool

    public init(isOn: Bool) {
        self.isOn = isOn
    }

    public var body: some View {
        ZStack(alignment: .leading) {
            Color.clear
                .crayonBackground(.capsule, fill: isOn ? CrayonStyle.skyPill : CrayonStyle.paper,
                                  seed: CrayonStyle.Seed.crayonSwitch)
            Color.clear
                .frame(width: Self.knob, height: Self.knob)
                .crayonBackground(.circle, fill: CrayonStyle.paper, seed: CrayonStyle.Seed.crayonSwitch + 1)
                .overlay { if isOn { CheckMark(isDone: true, size: 28) } }
                .offset(x: isOn ? 48 : 4)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .animation(.easeInOut(duration: 0.2), value: isOn)
        .accessibilityHidden(true)
    }
}

/// Spec "S4 · Almost done": one row of the feature-switch list, 120 tall: the picture 56, the title
/// (body bold) over one caption line, and the control at the right end of the row. The whole row is
/// the touch area; VoiceOver reads it as a switch with the title.
public struct SettingRow<Picture: View>: View {
    public static var height: CGFloat { 120 }

    private let title: String
    private let caption: String
    private let captionIsWarning: Bool
    private let isOn: Bool
    private let picture: Picture
    private let action: () -> Void

    public init(title: String, caption: String, captionIsWarning: Bool = false, isOn: Bool,
                action: @escaping () -> Void, @ViewBuilder picture: () -> Picture) {
        self.title = title
        self.caption = caption
        self.captionIsWarning = captionIsWarning
        self.isOn = isOn
        self.action = action
        self.picture = picture()
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.m + Spacing.xs) {
                picture.frame(width: 56, height: 56)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink).lineLimit(1)
                    Text(caption).crayonType(.caption)
                        .foregroundStyle(captionIsWarning ? CrayonColor.lateText : CrayonColor.softText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Spacing.m)
                CrayonSwitch(isOn: isOn)
            }
            .frame(height: Self.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(caption)
        .accessibilityAddTraits(.isToggle)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
