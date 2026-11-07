import CoreGraphics
import Foundation

/// One slot as the pie clock draws it. Minutes after midnight; `end` may pass 1440 for a slot
/// that runs across midnight (merged sleep).
public struct ClockSector: Hashable, Sendable {
    public var start: Int
    public var end: Int
    public var style: ClockSlotStyle
    /// A `KitSlot` raw value, or `nil` for no picture.
    public var iconName: String?
    public var isCurrent: Bool
    public var showsStar: Bool
    /// 0 day template, 1 every week, 2 just once: which one to keep when short slots collide.
    public var priority: Int

    public init(start: Int, end: Int, style: ClockSlotStyle, iconName: String?, isCurrent: Bool, showsStar: Bool,
                priority: Int) {
        self.start = start
        self.end = end
        self.style = style
        self.iconName = iconName
        self.isCurrent = isCurrent
        self.showsStar = showsStar
        self.priority = priority
    }
}

/// The geometry rules of the 24-hour clock (board A1), kept free of drawing so they can be tested.
public enum PieClockLayout {
    /// Clockwise from 12 o'clock: midnight at the top, noon at the bottom, 15° per hour.
    public static func degrees(minute: Int) -> Double { Double(minute) * 0.25 }

    /// Shortest slot the clock draws (2.5°).
    static let minimumMinutes = 10
    /// How far a short slot may be pushed to make room for its neighbour.
    static let maximumPush = 5

    /// Sectors ready to draw: same-style slots touching at midnight merge into one, short slots get
    /// the minimum width (and no picture), and short neighbours push apart; if they still collide,
    /// the lower-priority one is left out of the drawing.
    public static func drawable(_ sectors: [ClockSector]) -> [ClockSector] {
        var items = mergeAcrossMidnight(sectors).sorted { $0.start < $1.start }
        var isShort: [Bool] = []
        for index in items.indices {
            let length = items[index].end - items[index].start
            isShort.append(length < minimumMinutes)
            if length < minimumMinutes {
                let mid = (items[index].start + items[index].end) / 2
                items[index].start = mid - minimumMinutes / 2
                items[index].end = mid + minimumMinutes / 2
                items[index].iconName = nil
            }
        }

        var result: [ClockSector] = []
        var resultShort: [Bool] = []
        for (index, var sector) in items.enumerated() {
            guard var previous = result.last, previous.end > sector.start else {
                result.append(sector)
                resultShort.append(isShort[index])
                continue
            }
            let previousShort = resultShort.last!
            switch (previousShort, isShort[index]) {
            case (true, true):
                let overlap = previous.end - sector.start
                let room = result.count > 1 ? previous.start - result[result.count - 2].end : maximumPush
                let back = max(0, min(maximumPush, (overlap + 1) / 2, room))
                previous.start -= back
                previous.end -= back
                let forward = min(maximumPush, overlap - back)
                sector.start += forward
                sector.end += forward
                result[result.count - 1] = previous
                if previous.end > sector.start {
                    if sector.priority > previous.priority {
                        result[result.count - 1] = sector
                        resultShort[resultShort.count - 1] = true
                    }
                    continue
                }
            case (false, true):
                result[result.count - 1].end = sector.start
            case (_, false):
                sector.start = previous.end
            }
            result.append(sector)
            resultShort.append(isShort[index])
        }
        return result.filter { $0.end > $0.start }
    }

    /// Picture size by slot length: 3 h and more 104, 1–3 h 84, 30–60 min 68, shorter none.
    public static func pictureSize(minutes: Int) -> CGFloat? {
        switch minutes {
        case 180...: 104
        case 60..<180: 84
        case 30..<60: 68
        default: nil
        }
    }

    /// Picture size and distance from the centre for a slot `minutes` long, or `nil` when no picture
    /// fits. Starts from the size by length, at 0.7 R; a wedge narrower than the picture moves it out
    /// toward the rim, then tries the next smaller size.
    public static func picture(minutes: Int, radius: CGFloat, hub: CGFloat) -> (size: CGFloat, distance: CGFloat)? {
        guard let preferred = pictureSize(minutes: minutes) else { return nil }
        let wedge = CGFloat(degrees(minute: minutes)) * .pi / 180
        for size in [104, 84, 68].map(CGFloat.init) where size <= preferred {
            let inner = hub + 8 + size / 2, outer = radius - 8 - size / 2
            guard inner <= outer else { continue }
            let preferredDistance = min(max(radius * 0.7, inner), outer)
            for distance in [preferredDistance, outer] where distance * wedge >= size {
                return (size, distance)
            }
        }
        return nil
    }

    private static func mergeAcrossMidnight(_ sectors: [ClockSector]) -> [ClockSector] {
        guard let early = sectors.firstIndex(where: { $0.start == 0 }),
              let late = sectors.firstIndex(where: { $0.end == 1440 }),
              early != late, sectors[early].style == sectors[late].style
        else { return sectors }
        var merged = sectors[late]
        merged.end = 1440 + sectors[early].end
        merged.isCurrent = sectors[early].isCurrent || sectors[late].isCurrent
        merged.showsStar = sectors[early].showsStar || sectors[late].showsStar
        merged.priority = max(sectors[early].priority, sectors[late].priority)
        return sectors.enumerated().filter { $0.offset != early && $0.offset != late }.map(\.element) + [merged]
    }
}
