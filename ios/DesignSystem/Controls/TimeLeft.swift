import SwiftUI

/// Minutes left, big: ink while there is time, late red at zero or below ("−2 min").
public struct TimeLeft: View {
    private let text: String
    private let isLate: Bool
    private let look: KidLook
    private let compact: Bool
    @Environment(\.sizing) private var sizing

    /// `text` ("19 min", "−2 min") comes from the caller (`TimeLeftText` in Domain); `isLate` draws
    /// it late red.
    /// `compact`: 72 bold beside a picture (home Kid A row, look ①, layout v17) instead of the
    /// display 96; "1h 20m" then fits the 272 beside the 96 picture.
    public init(_ text: String, isLate: Bool, look: KidLook = .day, compact: Bool = false) {
        self.text = text
        self.isLate = isLate
        self.look = look
        self.compact = compact
    }

    public var body: some View {
        let size = compact ? sizing.timeLeftCompact : sizing.size(of: .display)
        Text(text)
            .font(Font(FontRegistrar.font(size: size, weight: .bold)))
            .foregroundStyle(isLate ? CrayonColor.lateText : look.ink)
            .monospacedDigit()
            .lineLimit(1)
            // Line height 1.0: the box is as tall as the type (96 or 72 on the board), not the
            // font's taller default.
            .frame(height: size * CrayonType.display.lineHeight)
    }
}
