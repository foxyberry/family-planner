import SwiftUI

/// One day on the school calendar (spec K1 "Marks"): each kid's school day off as a diagonal band in
/// the kid's colour (one kid fills the cell; two or more split it), a public holiday as a red
/// numeral on a light red cell (inside a break the kid colour stays and the numeral is red), and
/// today as a dark disc behind the numeral. The cell keeps its colour under the disc.
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

    /// Board sizes: a month card's cell 36 × 28 (numeral 18, disc 24), an open month's 104 × 96
    /// (numeral 32 bold, disc 70).
    public enum Size: Sendable {
        case card, open

        public var board: CGSize {
            switch self {
            case .card: CGSize(width: 36, height: 28)
            case .open: CGSize(width: 104, height: 96)
            }
        }

        var numeral: CGFloat {
            switch self {
            case .card: 18
            case .open: 32
            }
        }

        var weight: UIFont.Weight {
            switch self {
            case .card: .medium
            case .open: .bold
            }
        }

        var disc: CGFloat {
            switch self {
            case .card: 24
            case .open: 70
            }
        }

        var corner: CGFloat {
            switch self {
            case .card: 6
            case .open: 16
            }
        }
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
            ground
            if mark.isToday {
                Circle().fill(CrayonColor.todayDisc).frame(width: sizing(size.disc), height: sizing(size.disc))
            }
            Text(mark.number)
                .font(Font(FontRegistrar.font(size: sizing(size.numeral), weight: size.weight)))
                .foregroundStyle(numeralColor)
                .lineLimit(1)
                .fixedSize()
        }
        .frame(width: sizing(size.board.width), height: sizing(size.board.height))
        .clipShape(RoundedRectangle(cornerRadius: sizing(size.corner)))
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

    /// Today: the disc's numeral. On a kid's colour (a crayon ground) the day colours stay at night,
    /// as labels on crayon on-states do (spec "Night mapping").
    private var numeralColor: Color {
        if mark.isToday { return CrayonColor.todayText }
        if !mark.kids.isEmpty { return mark.isHoliday ? CrayonColor.pictureLate : CrayonColor.pictureInk }
        return mark.isHoliday ? CrayonColor.lateText : CrayonColor.ink
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
