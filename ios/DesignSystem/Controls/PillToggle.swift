import CrayonKit
import SwiftUI

/// A pill that toggles (boards C2, S3: the bus numbers), 180 × 72: sky blue and bold when on, paper
/// when off. Several can be on at once; a row of them wraps (`PillToggleGrid`). A bus that changes
/// ("12 · 34 → 33", spec "Several buses", layout v61) is as wide as its text + 80.
public struct PillToggle: View {
    @Environment(\.sizing) private var sizing
    public static let size = CGSize(width: 180, height: 72)

    private let title: String
    private let isOn: Bool
    private let then: String?
    private let action: () -> Void

    /// `then`: a bus that changes (spec "Several buses", C2) reads "12 · 34 → 33" (`title` "12 · 34"),
    /// the arrow drawn; the pill is then as wide as its words + 80.
    public init(_ title: String, isOn: Bool, then: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.isOn = isOn
        self.then = then
        self.action = action
    }

    /// Layout v61: a plain pill is 180; a bus that changes is its words (bold, so on and off match)
    /// + the drawn arrow + 80 (C2 "12 · 34 → 33" is 280 on the 13").
    public static let textMargin: CGFloat = 80
    public static let arrow: CGFloat = 24

    /// The pill's width on `sizing`: worked out on the board, × s.
    public static func width(_ title: String, then: String?, sizing: Sizing) -> CGFloat {
        let board = Sizing.thirteenInch
        // A name longer than the 180 pill (a bundle, board F2) widens it to its bold words.
        guard let then else {
            return sizing(max(size.width, CrayonType.head.width(title, sizing: board, bold: true) + textMargin))
        }
        let words = CrayonType.head.width(title, sizing: board, bold: true) + CrayonType.head.width(then, sizing: board, bold: true)
        return sizing(words + 2 * Spacing.xs + arrow + textMargin)
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: sizing(Spacing.xs)) {
                Text(title)
                    .crayonType(.head, bold: isOn)
                    .foregroundStyle(isOn ? CrayonColor.pictureInk : CrayonColor.ink)
                    .lineLimit(1)
                if let then {
                    // Playpen Sans has no arrows: the arrow is drawn.
                    MarkerIcon(.arrowRight, size: sizing(Self.arrow), color: isOn ? CrayonColor.pictureInk : CrayonColor.ink)
                    Text(then)
                        .crayonType(.head, bold: isOn)
                        .foregroundStyle(isOn ? CrayonColor.pictureInk : CrayonColor.ink)
                        .lineLimit(1)
                }
            }
            // 180 × 72, × s (a bus that changes: its words + 80).
            .frame(width: Self.width(title, then: then, sizing: sizing)).frame(minHeight: sizing.tabHeight(Self.size.height))
            .partBackground(.capsule, fill: isOn ? CrayonStyle.skyPill : CrayonStyle.paper,
                            seed: CrayonStyle.Seed.tabs + 50)
        }
        .buttonStyle(.plain)
    }
}

/// `PillToggle`s in a form's control column, left to right 12 apart, wrapping onto more lines (gap
/// 12) when the next pill would pass the column: 3 plain pills of 180 on the 13", fewer when the
/// column cannot hold them; a wider pill (a bus that changes) wraps like the others.
public struct PillToggleGrid<Content: View>: View {
    private let controlWidth: CGFloat
    private let content: Content
    @Environment(\.sizing) private var sizing

    public init(controlWidth: CGFloat, @ViewBuilder content: () -> Content) {
        self.controlWidth = controlWidth
        self.content = content()
    }

    public var body: some View {
        TabFlow(spacing: sizing(Spacing.sm)) { content }
            .frame(width: controlWidth, alignment: .leading)
    }
}
