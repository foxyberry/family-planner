import SwiftUI

/// One day on the school calendar (spec K1 "Marks", layout v74): each kid's school day off as a
/// diagonal band in the kid's colour (one kid fills the cell; two or more split it); a public holiday
/// as a red numeral (24 bold and up) on the light red holiday colour: the whole cell, or inside a kid's
/// colour a chip under the numeral, so red never sits on a kid colour; today as a dark pill (a disc
/// when open) behind the numeral. The cell keeps its colour under the pill.
///
/// Flat fills, not crayon outlines: a year has about 500 cells, and the month card around them
/// carries the crayon line.
public struct CalendarCell: View {
    /// What a day shows. The caller gives the numeral as text (parts take their words from callers).
    public struct Mark: Equatable, Sendable {
        public var number: String
        /// The colour index of each kid off that day, in the family's order.
        public var kids: [Int]
        public var isHoliday: Bool
        public var isToday: Bool

        public init(number: String, kids: [Int] = [], isHoliday: Bool = false, isToday: Bool = false) {
            self.number = number
            self.kids = kids
            self.isHoliday = isHoliday
            self.isToday = isToday
        }
    }

    /// Board sizes (layout v74): a month card's cell 36 × 28 (numeral 24, today pill 38 × 28, holiday
    /// chip 32 × 24); an open month's 104 × 96 (numeral 32 bold, today disc 70, chip 76 × 64); a key
    /// swatch 48 × 36 (numeral 24 bold, the pill fills it).
    public enum Size: Sendable {
        case card, open, legend

        public var board: CGSize {
            switch self {
            case .card: CGSize(width: 36, height: 28)
            case .open: CGSize(width: 104, height: 96)
            case .legend: CGSize(width: 48, height: 36)
            }
        }

        public var numeral: CGFloat {
            switch self {
            case .card, .legend: 24
            case .open: 32
            }
        }

        /// Today's mark: a pill on a card and in the key, a disc when open.
        public var today: CGSize {
            switch self {
            case .card: CGSize(width: 38, height: 28)
            case .open: CGSize(width: 70, height: 70)
            case .legend: CGSize(width: 48, height: 36)
            }
        }

        /// The light red chip under a holiday's numeral inside a kid's colour.
        public var chip: CGSize {
            switch self {
            case .card: CGSize(width: 32, height: 24)
            case .open: CGSize(width: 76, height: 64)
            case .legend: CGSize(width: 42, height: 32)
            }
        }

        var corner: CGFloat {
            switch self {
            case .card, .legend: 6
            case .open: 16
            }
        }

        /// Plain numerals: regular on cards, bold when open and in the key.
        var bold: Bool { self != .card }
    }

    private let mark: Mark
    private let size: Size
    @Environment(\.sizing) private var sizing

    public init(_ mark: Mark, size: Size) {
        self.mark = mark
        self.size = size
    }

    public var body: some View {
        ZStack {
            ground.clipShape(RoundedRectangle(cornerRadius: sizing(size.corner)))
            if mark.isHoliday && !mark.kids.isEmpty && !mark.isToday {
                RoundedRectangle(cornerRadius: sizing(size.corner))
                    .fill(CrayonColor.holidayGround)
                    .frame(width: sizing(size.chip.width), height: sizing(size.chip.height))
            }
            if mark.isToday {
                // A pill as tall as the cell (it may stand a little past a card cell's sides).
                Capsule().fill(CrayonColor.todayDisc)
                    .frame(width: sizing(size.today.width), height: sizing(size.today.height))
            }
            Text(mark.number)
                .font(Font(FontRegistrar.font(size: sizing(size.numeral), weight: isBold ? .bold : .medium)))
                .foregroundStyle(numeralColor)
                .lineLimit(1)
                .fixedSize()
        }
        .frame(width: sizing(size.board.width), height: sizing(size.board.height))
    }

    @ViewBuilder private var ground: some View {
        if !mark.kids.isEmpty {
            ZStack {
                ForEach(Array(mark.kids.enumerated()), id: \.offset) { index, colorIndex in
                    DiagonalBand(index: index, count: mark.kids.count).fill(CrayonColor.kidOff(colorIndex))
                }
            }
        } else if mark.isHoliday {
            CrayonColor.holidayGround
        } else {
            Color.clear
        }
    }

    /// Red numerals are bold everywhere (spec: 24 bold and up, so the large-text 3 : 1 applies).
    private var isBold: Bool { size.bold || (mark.isHoliday && !mark.isToday) }

    private var numeralColor: Color {
        if mark.isToday { return CrayonColor.todayText }
        if mark.isHoliday { return CrayonColor.lateText }
        if let first = mark.kids.first { return CrayonColor.kidOffText(first) }
        return CrayonColor.ink
    }
}

/// Band `index` of `count` across a rect, cut by lines parallel to the bottom-left to top-right
/// diagonal: two kids split the cell into two triangles, three or four into stripes (spec K1 "Data
/// and states").
struct DiagonalBand: Shape {
    let index: Int
    let count: Int

    func path(in rect: CGRect) -> Path {
        // In the unit square a line x + y = c; band i runs from c = 2i/n to 2(i+1)/n.
        let low = 2 * CGFloat(index) / CGFloat(count), high = 2 * CGFloat(index + 1) / CGFloat(count)
        let far: CGFloat = 4
        let unit = Path { path in
            path.move(to: CGPoint(x: low + far, y: -far))
            path.addLine(to: CGPoint(x: -far, y: low + far))
            path.addLine(to: CGPoint(x: -far, y: high + far))
            path.addLine(to: CGPoint(x: high + far, y: -far))
            path.closeSubpath()
        }
        // Keep the first band's top-left corner and the last band's bottom-right corner whole.
        let clipped = unit.intersection(Path(CGRect(x: 0, y: 0, width: 1, height: 1)))
        return clipped.applying(CGAffineTransform(scaleX: rect.width, y: rect.height)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY)))
    }
}
