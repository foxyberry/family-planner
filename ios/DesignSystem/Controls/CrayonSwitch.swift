import CrayonKit
import SwiftUI

/// Spec "S4 · Almost done" `CrayonSwitch` (board close-up, 2026-11-09): in a 96 × 52 box, a thin pill
/// track 92 × 28 (sky `tab-on` when on, paper `tab-off` when off) and a 44 paper knob, taller than the
/// track, at x 48 on / x 4 off with the check picture 28 inside it when on. The knob slides in 0.2 s.
/// Its row (`SettingRow`) or the caller's button is the touch area. Off (`isEnabled: false`, G2b's
/// Medal without a trip) it draws the one off look, 40 %, and takes no taps; the caller's button takes
/// none either (`allowsHitTesting` with the same flag; `.disabled` would dim it twice).
public struct CrayonSwitch: View {
    public static let size = CGSize(width: 96, height: 52)
    private static let knob: CGFloat = 44

    private let isOn: Bool
    private let isEnabled: Bool
    @Environment(\.sizing) private var sizing

    public init(isOn: Bool, isEnabled: Bool = true) {
        self.isOn = isOn
        self.isEnabled = isEnabled
    }

    public var body: some View {
        // 96 × 52 and the knob 44, × s; the track and the knob's travel keep the board's proportions.
        let box = sizing.switchSize, knob = sizing.switchKnob
        ZStack(alignment: .leading) {
            Color.clear
                .frame(width: box.width * 92 / 96, height: box.height * 28 / 52)
                .crayonBackground(.capsule, fill: isOn ? CrayonStyle.skyPill : CrayonStyle.paper,
                                  seed: CrayonStyle.Seed.crayonSwitch, marker: .thin)
                .offset(x: sizing(2))
            Color.clear
                .frame(width: knob, height: knob)
                .crayonBackground(.circle, fill: CrayonStyle.paper, seed: CrayonStyle.Seed.crayonSwitch + 1,
                                  marker: .thin)
                .overlay { if isOn { CheckMark(isDone: true, size: 28) } }
                .offset(x: isOn ? box.width - knob - box.width * 4 / 96 : box.width * 4 / 96)
        }
        .frame(width: box.width, height: box.height)
        .animation(.easeInOut(duration: 0.2), value: isOn)
        .offLook(isEnabled)
    }
}

/// Spec "S4 · Almost done": one row of the feature-switch list, 120 tall: the picture 56, the title
/// (body bold) over one caption line, and the control at the right end of the row. The whole row is
/// the touch area.
public struct SettingRow<Picture: View>: View {
    @Environment(\.sizing) private var sizing
    public static var height: CGFloat { 120 }

    private let title: String
    private let caption: String
    private let captionIsWarning: Bool
    private let isOn: Bool
    private let picture: Picture
    private let action: () -> Void
    private let hugs: Bool

    /// `hugs`: a row on a form card's rhythm (board S4, layout v56): as tall as its words, the words
    /// 24 after the picture, rows `formRowGap` apart. Otherwise the 120 list row.
    public init(title: String, caption: String, captionIsWarning: Bool = false, isOn: Bool, hugs: Bool = false,
                action: @escaping () -> Void, @ViewBuilder picture: () -> Picture) {
        self.hugs = hugs
        self.title = title
        self.caption = caption
        self.captionIsWarning = captionIsWarning
        self.isOn = isOn
        self.action = action
        self.picture = picture()
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: sizing(hugs ? Spacing.m : Spacing.m + Spacing.xs)) {
                picture.frame(width: sizing.settingRowPicture, height: sizing.settingRowPicture)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).crayonType(.body, bold: true).foregroundStyle(CrayonColor.ink).lineLimit(1)
                    Text(caption).crayonType(.caption)
                        .foregroundStyle(captionIsWarning ? CrayonColor.hurry : CrayonColor.softText)
                        // At most 2 lines.
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // The words take all the width the switch leaves (a spacer beside them took half of it
                // and wrapped one-line captions).
                .frame(maxWidth: .infinity, alignment: .leading)
                CrayonSwitch(isOn: isOn)
            }
            // A list row is 120 and a two-line caption may grow it (up to the 140 pitch); a hugging
            // row is as tall as its words.
            .frame(minHeight: hugs ? 0 : sizing.settingRowHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
