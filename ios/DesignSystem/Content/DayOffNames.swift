import SwiftUI
import UIKit

/// The open month's names of the days off (board K1o, spec K1 "Names of the days off", layout v82):
/// one item per day off, by date, 24 apart: a swatch 48 × 36 (a `CalendarCell`, as in the key), then
/// the date(s) (24 bold) over the name (24 `softText`, up to two lines). Items fill the column's height;
/// when the rest do not fit, the last line reads `more(n)`. The column never scrolls.
public struct DayOffNames: View {
    public struct Item: Equatable, Sendable, Identifiable {
        public var swatch: CalendarCell.Mark
        public var date: String
        public var name: String
        public var id: String { date + name }

        public init(swatch: CalendarCell.Mark, date: String, name: String) {
            self.swatch = swatch
            self.date = date
            self.name = name
        }
    }

    private let items: [Item]
    private let more: (Int) -> String
    @Environment(\.sizing) private var sizing

    /// `more`: the last line's words for the `n` items left out ("+2 more"), from the caller.
    public init(items: [Item], more: @escaping (Int) -> String) {
        self.items = items
        self.more = more
    }

    /// Board values: the column 320 wide, swatch 48 × 36 with 12 to the words, items 24 apart.
    static let width: CGFloat = 320
    static let swatchGap: CGFloat = 12
    static let gap: CGFloat = 24
    static let type: CGFloat = 24

    public var body: some View {
        GeometryReader { proxy in
            let shown = Self.fitting(items.map(\.name), height: proxy.size.height / sizing.s)
            VStack(alignment: .leading, spacing: sizing(Self.gap)) {
                ForEach(items.prefix(shown)) { item in
                    HStack(alignment: .top, spacing: sizing(Self.swatchGap)) {
                        CalendarCell(item.swatch, size: .legend)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(item.date).crayonType(.caption, bold: true).foregroundStyle(CrayonColor.ink).lineLimit(1)
                            Text(item.name).crayonType(.caption).foregroundStyle(CrayonColor.softText).lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if shown < items.count {
                    Text(more(items.count - shown)).crayonType(.caption).foregroundStyle(CrayonColor.softText)
                        .lineLimit(1)
                }
            }
            .frame(width: proxy.size.width, alignment: .topLeading)
        }
    }

    /// How many of the items fit in `height` (board points), keeping room for the "+n more" line
    /// when some are left out. A name takes one or two lines of 24 at the words' width.
    static func fitting(_ names: [String], height: CGFloat) -> Int {
        let line = FontRegistrar.font(size: type, weight: .medium).lineHeight
        let words = width - CalendarCell.Size.legend.board.width - swatchGap
        let font = FontRegistrar.font(size: type, weight: .medium)
        let heights = names.map { name -> CGFloat in
            let wide = (name as NSString).size(withAttributes: [.font: font]).width
            return line * (wide > words ? 3 : 2)
        }
        func total(_ count: Int, more: Bool) -> CGFloat {
            let rows = heights.prefix(count).reduce(0, +) + gap * CGFloat(max(count - 1, 0))
            return more ? rows + (count > 0 ? gap : 0) + line : rows
        }
        if total(heights.count, more: false) <= height { return heights.count }
        var count = heights.count - 1
        while count > 0, total(count, more: true) > height { count -= 1 }
        return count
    }
}
