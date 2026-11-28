import SwiftUI

/// A month on the school calendar (board K1, spec K1 "Layout", layout v74): white paper with a marker edge, the
/// month's name, the weekday row and six rows of day cells (`CalendarCell`), Saturday and Sunday
/// lightly shaded. `.card` is one of the year's twelve (312 × 268); `.open` is the month opened over
/// the year (1200 × 800, board K1o, layout v82) with its days off named in a column right of the grid,
/// whose "×" the screen places on it.
public struct MonthCard: View {
    /// Board lines inside the card, measured from boards K1 and K1o (layout v82).
    public enum Size: Sendable {
        case card, open

        /// The card's board size.
        public var board: CGSize {
            switch self {
            case .card: CGSize(width: 312, height: 268)
            case .open: CGSize(width: 1200, height: 800)
            }
        }

        public var cell: CalendarCell.Size { self == .card ? .card : .open }
        /// The month's name 20 (open: 40) in from the left; its baseline (card 30 bold: 43; open 48 bold: 80).
        public var titleLeft: CGFloat { self == .card ? 20 : 40 }
        public var titleBaseline: CGFloat { self == .card ? 43 : 80 }
        public var titleType: CrayonType { self == .card ? .body : .title }
        /// The weekday row's baseline (layout v74: card "M T W T F S S" 24 on 76; open "Mon … Sun" 24
        /// on 140). Nothing on the card is under 24.
        public var weekdayBaseline: CGFloat { self == .card ? 76 : 140 }
        public var weekdaySize: CGFloat { 24 }
        /// The first cell's top-left and the pitch: card 36 × 28 on 40 / 30 from (18, 82), numerals on
        /// the cell's middle (first baseline 254 − 148 = 106); open 104 × 96 on 112 / 104 from (40, 148).
        public var gridOrigin: CGPoint { self == .card ? CGPoint(x: 18, y: 82) : CGPoint(x: 40, y: 148) }
        public var pitch: CGSize { self == .card ? CGSize(width: 40, height: 30) : CGSize(width: 112, height: 104) }
        /// Board K1o (layout v82): the names column, x 928 on the board (840 in), 320 wide, from the
        /// weekday row's top (272, 112 in) down to 40 above the card's bottom.
        public var names: CGRect { CGRect(x: 840, y: 112, width: 320, height: 800 - 40 - 112) }
    }

    private let title: String
    private let weekdays: [String]
    private let weeks: [[CalendarCell.Mark?]]
    private let size: Size
    private let seed: UInt32
    private let names: [DayOffNames.Item]
    private let more: (Int) -> String
    @Environment(\.sizing) private var sizing

    /// `weekdays`: the seven column labels, Monday first. `weeks`: six rows of seven, nil outside
    /// the month. `seed`: a card's index, so neighbours' crayon edges differ.
    /// `names`: the open month's days off by name (`.open` only); `more`: their "+n more" words.
    public init(title: String, weekdays: [String], weeks: [[CalendarCell.Mark?]], size: Size, seed: UInt32 = 0,
                names: [DayOffNames.Item] = [], more: @escaping (Int) -> String = { _ in "" }) {
        self.title = title
        self.weekdays = weekdays
        self.weeks = weeks
        self.size = size
        self.seed = seed
        self.names = names
        self.more = more
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            weekendShade
            Text(title).crayonType(size.titleType, bold: true).foregroundStyle(CrayonColor.ink).lineLimit(1)
                .place(left: sizing(size.titleLeft), baseline: sizing(size.titleBaseline))
            ForEach(Array(weekdays.enumerated()), id: \.offset) { column, letter in
                Text(letter)
                    .font(Font(FontRegistrar.font(size: sizing(size.weekdaySize), weight: .medium)))
                    .foregroundStyle(CrayonColor.softText).lineLimit(1).fixedSize()
                    .frame(width: sizing(size.cell.board.width))
                    .place(left: cellRect(row: 0, column: column).minX, baseline: sizing(size.weekdayBaseline))
            }
            if size == .open, !names.isEmpty {
                DayOffNames(items: names, more: more)
                    .place(CGRect(x: sizing(size.names.minX), y: sizing(size.names.minY),
                                  width: sizing(size.names.width), height: sizing(size.names.height)))
            }
            ForEach(Array(weeks.enumerated()), id: \.offset) { row, week in
                ForEach(Array(week.enumerated()), id: \.offset) { column, mark in
                    if let mark {
                        CalendarCell(mark, size: size.cell).place(cellRect(row: row, column: column))
                    }
                }
            }
        }
        .frame(width: sizing(size.board.width), height: sizing(size.board.height), alignment: .topLeading)
        .partBackground(.roundedRect(cornerRadius: 24), fill: CrayonStyle.paper, seed: CrayonStyle.Seed.month + seed,
                        tap: .frame, inset: MonthCard.outlineInset)
    }

    /// Saturday and Sunday: one light band per column, under all six rows.
    private var weekendShade: some View {
        ForEach([5, 6], id: \.self) { column in
            let top = cellRect(row: 0, column: column), bottom = cellRect(row: MonthCard.rows - 1, column: column)
            RoundedRectangle(cornerRadius: sizing(size.cell.corner))
                .fill(CrayonColor.weekendShade)
                .place(CGRect(x: top.minX, y: top.minY, width: top.width, height: bottom.maxY - top.minY))
        }
    }

    /// Six week rows on every card (`MonthGrid` lays every month out in six).
    public static let rows = 6

    /// The card's crayon line runs on its box, the board's visible edge (layout README), not the
    /// usual 6 inside (spec "Crayon part inset"): board K1 (v74) fits six week rows only to its box
    /// (the sixth row ends 8 above it).
    public static let outlineInset: CGFloat = 0

    /// A day's cell in screen points inside the card.
    private func cellRect(row: Int, column: Int) -> CGRect {
        let origin = size.gridOrigin, pitch = size.pitch, cell = size.cell.board
        return sizing.rectInPart(origin.x + pitch.width * CGFloat(column), origin.y + pitch.height * CGFloat(row),
                                 cell.width, cell.height)
    }
}

extension Sizing {
    /// A board rect inside a part, × s, with no screen offset (the part sits wherever it is placed).
    func rectInPart(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
        CGRect(x: x * s, y: y * s, width: w * s, height: h * s)
    }
}
