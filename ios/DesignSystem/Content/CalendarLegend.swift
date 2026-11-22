import SwiftUI

/// The school calendar's key (board K1, spec K1 "Layout"): for each kid their face (36) and a day-off
/// swatch with "{Name} off", a split swatch "Both off", a light red swatch with a red numeral
/// "Public holiday", and a today disc "Today". Swatches are `CalendarCell`s, so the key draws exactly
/// what the months draw (swatches 48 × 36, numerals 24 bold; layout v74). Face, swatch and label sit
/// 8 apart; items run left to right, 24 apart, and wrap to a second line 8 below.
public struct CalendarLegend: View {
    public struct Item: Equatable, Sendable {
        public var face: KidFace.Badge?
        public var swatch: CalendarCell.Mark
        public var label: String

        public init(face: KidFace.Badge? = nil, swatch: CalendarCell.Mark, label: String) {
            self.face = face
            self.swatch = swatch
            self.label = label
        }
    }

    private let items: [Item]
    @Environment(\.sizing) private var sizing

    public init(items: [Item]) {
        self.items = items
    }

    public var body: some View {
        TabFlow(spacing: sizing(24), lineSpacing: sizing(8)) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: sizing(8)) {
                    if let face = item.face {
                        KidFace(face, size: sizing(36))
                    }
                    CalendarCell(item.swatch, size: .legend)
                    Text(item.label).crayonType(.caption).foregroundStyle(CrayonColor.ink).lineLimit(1).fixedSize()
                }
                .frame(height: sizing(36))
            }
        }
    }
}
