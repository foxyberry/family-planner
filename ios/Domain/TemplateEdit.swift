import Foundation
import Strings

/// Editing one day on the G1 clock (spec "C6 · Our day", Drag rules): the day template and the
/// items on top of it. Every boundary between two drawn slices is a knob; moving a template knob
/// moves the end of one slice and the start of the next together, moving an item's edge moves only
/// the item (the template underneath stays). Times snap to 5 minutes, no slice is shorter than 15
/// minutes and knobs never cross. School's edges move like any other (layout v37). There are no
/// forced gaps: slices may touch exactly, and free time shorter than 15 minutes never stays (it
/// joins the slice beside it). The two sleep halves meet at midnight, which has no knob. One Undo
/// covers every change: drags, typed times, skips, removes and adds.
public struct TemplateEdit: Equatable, Sendable {
    public struct Knob: Equatable, Sendable {
        public var minute: Int
        /// The slice that ends at this knob and the one that starts there.
        public var before: Int
        public var after: Int
    }

    /// What a move did: moved to the snapped minute, stopped at a limit (bump haptic), or had no knob
    /// to move (the day's first start or last end).
    public enum Move: Equatable, Sendable {
        case moved(Int)
        case stopped(Int)
        case noKnob
    }

    public static let snap = 5
    public static let shortest = 15
    /// Spec "Add between two slices": a "+" on a knob adds this many minutes.
    public static let between = 30
    /// Spec "Tapping +": the free-paper "+" adds the first hour.
    public static let firstHour = 60

    public private(set) var blocks: [RoutineBlock]
    /// The day's items, drawn over the template (removed ones stay here until Save, for Undo).
    public private(set) var items: [ClockItem]

    private struct Snapshot: Equatable, Sendable {
        var blocks: [RoutineBlock]
        var items: [ClockItem]
    }

    private var history: [Snapshot] = []
    /// Changes taken back by Undo since the last change, for Redo (spec "Grown-up mode", G1).
    private var future: [Snapshot] = []

    public init(blocks: [RoutineBlock], items: [ClockItem] = []) {
        self.blocks = blocks.sorted { $0.start < $1.start }
        self.items = items
        closeShortGaps()
    }

    /// The template's own knobs (where two template slices touch), items aside.
    public var knobs: [Knob] {
        blocks.indices.dropLast().compactMap { i in
            guard blocks[i].end == blocks[i + 1].start else { return nil }
            return Knob(minute: blocks[i].end, before: i, after: i + 1)
        }
    }

    /// True when there is something to undo since the last save.
    public var isChanged: Bool { !history.isEmpty }
    public var canRedo: Bool { !future.isEmpty }

    /// Call once when a drag starts (or before a typed change), so undo steps back a whole change.
    /// A new change ends what Redo could put back.
    public mutating func beginChange() {
        history.append(Snapshot(blocks: blocks, items: items))
        future.removeAll()
    }

    /// Moves a template knob. Free time beside it may shrink to nothing here; `closeShortGaps`
    /// (on release, after a typed time) folds what is left under 15 minutes into the moved slice.
    public mutating func moveKnob(_ index: Int, to minute: Int) -> Move {
        let knob = knobs[index]
        let lowest = blocks[knob.before].start + (blocks[knob.before].kind == .free ? 0 : Self.shortest)
        let highest = blocks[knob.after].end - (blocks[knob.after].kind == .free ? 0 : Self.shortest)
        return move(.blocks(before: knob.before), to: minute, within: lowest...max(lowest, highest))
    }

    /// A typed start time: moves the knob before the slice, with the same rules.
    public mutating func setStart(ofBlock block: Int, to minute: Int) -> Move {
        guard let index = knobs.firstIndex(where: { $0.after == block }) else { return .noKnob }
        beginChange()
        let move = moveKnob(index, to: minute)
        closeShortGaps(favoring: block)
        return move
    }

    /// A typed end time: moves the knob after the slice, with the same rules.
    public mutating func setEnd(ofBlock block: Int, to minute: Int) -> Move {
        guard let index = knobs.firstIndex(where: { $0.before == block }) else { return .noKnob }
        beginChange()
        let move = moveKnob(index, to: minute)
        closeShortGaps(favoring: block)
        return move
    }

    /// Spec "No forced gaps": free time under 15 minutes never stays. A free slice that short joins
    /// the slice that was just moved (`favoring`, when it is beside it), else the slice before it;
    /// a bare gap between two slices is closed the same way. Returns the favoured slice's new index.
    @discardableResult
    public mutating func closeShortGaps(favoring favored: Int? = nil) -> Int? {
        var keep = favored
        var index = 0
        while index < blocks.count {
            let block = blocks[index]
            let short = block.kind == .free && block.end - block.start < Self.shortest && blocks.count > 1
            guard short else {
                // A bare gap under 15 minutes after this slice: the slice runs on to the next one.
                if index + 1 < blocks.count, blocks[index + 1].start > block.end,
                   blocks[index + 1].start - block.end < Self.shortest {
                    blocks[index].end = blocks[index + 1].start
                }
                index += 1
                continue
            }
            let hasBefore = index > 0 && blocks[index - 1].end == block.start
            let hasAfter = index + 1 < blocks.count && blocks[index + 1].start == block.end
            let toAfter = hasAfter && (keep == index + 1 || !hasBefore)
            if toAfter {
                blocks[index + 1].start = block.start
            } else if hasBefore {
                blocks[index - 1].end = block.end
            } else {
                index += 1
                continue
            }
            blocks.remove(at: index)
            if let k = keep, k > index { keep = k - 1 }
        }
        return keep
    }

    /// "Remove" on All days: blank paper over the same span, joined with free time right before or
    /// after it, so the day can lose slices. School too (after its ConfirmCard). Returns the free
    /// slice's index.
    @discardableResult
    public mutating func makeFree(_ block: Int) -> Int {
        guard blocks[block].kind != .free else { return block }
        beginChange()
        var index = block
        blocks[index] = Self.free(from: blocks[index].start, to: blocks[index].end)
        if index + 1 < blocks.count, blocks[index + 1].kind == .free, blocks[index + 1].start == blocks[index].end {
            blocks[index].end = blocks[index + 1].end
            blocks.remove(at: index + 1)
        }
        if index > 0, blocks[index - 1].kind == .free, blocks[index - 1].end == blocks[index].start {
            blocks[index - 1].end = blocks[index].end
            blocks.remove(at: index)
            index -= 1
        }
        return index
    }

    /// Board G1g: "Skip this day" / "Bring back" on a slice of this day's template. One change for
    /// Undo. Free time is never skipped; School can be (a sick day).
    public mutating func setSkipped(_ block: Int, _ skipped: Bool) {
        guard blocks.indices.contains(block), blocks[block].kind != .free,
              blocks[block].isSkipped != skipped else { return }
        beginChange()
        blocks[block].isSkipped = skipped
    }

    private static func free(from start: Int, to end: Int) -> RoutineBlock {
        RoutineBlock(title: L10n.tr("home.hub.free"), iconName: "", kind: .free, start: start, end: end)
    }

    /// Takes back the last change (one finished drag, one typed time, one skip, remove or add).
    public mutating func undo() {
        guard let last = history.popLast() else { return }
        future.append(Snapshot(blocks: blocks, items: items))
        restore(last)
    }

    /// Puts back the change Undo took back last.
    public mutating func redo() {
        guard let next = future.popLast() else { return }
        history.append(Snapshot(blocks: blocks, items: items))
        restore(next)
    }

    private mutating func restore(_ snapshot: Snapshot) {
        blocks = snapshot.blocks
        items = snapshot.items
    }

    /// The blocks as they were at the last save (or when the edit began).
    public var savedBlocks: [RoutineBlock] { history.first?.blocks ?? blocks }
    /// The items as they were at the last save (or when the edit began).
    public var savedItems: [ClockItem] { history.first?.items ?? items }
    /// The day template differs from the last save (a Save writes it only then).
    public var isTemplateChanged: Bool { blocks != savedBlocks }

    /// The first slice that differs from the saved blocks (board G1d names it), skipping free time.
    public var firstChange: RoutineBlock? {
        let saved = savedBlocks
        return blocks.enumerated().first { index, block in
            block.kind != .free && (index >= saved.count || saved[index] != block)
        }?.element
    }

    /// The first item added, moved, skipped or removed since the last save (G1d when the template
    /// did not change).
    public var firstItemChange: ClockItem? {
        let saved = savedItems
        return items.sorted { $0.start < $1.start }.first { item in saved.first { $0.id == item.id } != item }
    }

    /// A change that applies to a series from a date on (an All days save asks G5 for it): a new
    /// or removed every-week item, or one with new times.
    public var hasSeriesChange: Bool {
        let saved = savedItems
        return items.contains { item in
            guard item.isRepeating else { return false }
            guard let was = saved.first(where: { $0.id == item.id }) else { return item.isNew }
            return item.isRemoved != was.isRemoved || item.start != was.start || item.end != was.end
        }
    }

    /// After a save the edit starts again from the saved day: nothing to undo or redo.
    public mutating func markSaved() {
        history.removeAll()
        future.removeAll()
    }
}

// MARK: - Items on the clock

public extension TemplateEdit {
    /// What the clock draws: template slices cut around the items, as on the kid clock (just once >
    /// every week > template; between equals the later start wins), sorted.
    var slices: [ClockSlice] {
        var candidates: [ClockSlice] = blocks.enumerated().map { index, block in
            ClockSlice(source: .block(index), title: block.title, iconName: block.iconName, kind: block.kind,
                       start: block.start, end: block.end, isSkipped: block.isSkipped, priority: 0)
        }
        for item in items where !item.isRemoved {
            candidates.append(ClockSlice(source: .item(item.id), title: item.title, iconName: item.iconName,
                                         kind: item.kind, start: item.start, end: item.end, isSkipped: item.isSkipped,
                                         priority: item.isRepeating ? 1 : 2))
        }
        candidates.sort { ($0.priority, $0.start) > ($1.priority, $1.start) }
        var claimed: [Range<Int>] = []
        var result: [ClockSlice] = []
        for slice in candidates {
            let start = max(0, slice.start), end = min(1440, slice.end)
            guard start < end else { continue }
            for piece in DayPlanner.subtract(claimed, from: start..<end) {
                var part = slice
                part.start = piece.lowerBound
                part.end = piece.upperBound
                result.append(part)
                claimed.append(piece)
            }
        }
        return result.sorted { $0.start < $1.start }
    }

    /// Every knob on the drawn clock, in day order.
    var clockKnobs: [DayKnob] {
        let slices = self.slices
        return slices.indices.dropLast().compactMap { i in
            let a = slices[i], b = slices[i + 1]
            guard a.end == b.start, let edge = edge(between: a, b) else { return nil }
            let shows = !a.isItem && !b.isItem && a.kind != .free && b.kind != .free
            return DayKnob(minute: a.end, edge: edge, before: a.source, after: b.source, showsAdd: shows)
        }
    }

    private func edge(between a: ClockSlice, _ b: ClockSlice) -> DayKnob.Edge? {
        switch (a.source, b.source) {
        case let (.block(x), .block):
            // Free time squeezed to nothing mid-drag still leaves the dragged knob in place.
            blocks[x].end == a.end && x + 1 < blocks.count ? .blocks(before: x) : nil
        case let (.item(x), .block):
            item(x)?.isAnchored == false ? .itemEnd(x) : nil
        case let (.block, .item(y)):
            item(y)?.isAnchored == false ? .itemStart(y) : nil
        case let (.item(x), .item(y)):
            item(x)?.isAnchored == false && item(y)?.isAnchored == false ? .items(end: x, start: y) : nil
        }
    }

    func item(_ id: ScheduleItem.ID) -> ClockItem? { items.first { $0.id == id } }

    /// How far a knob can go (taken when its drag starts): a slice keeps 15 minutes (free time may
    /// shrink to nothing), a template knob never goes under an item, an item edge never passes the
    /// next knob.
    func range(of edge: DayKnob.Edge) -> ClosedRange<Int> {
        let slices = self.slices
        let short = { (slice: ClockSlice) in slice.kind == .free ? 0 : Self.shortest }
        var lowest = 0, highest = 1440
        switch edge {
        case let .blocks(x):
            let minute = blocks[x].end
            lowest = blocks[x].start + (blocks[x].kind == .free ? 0 : Self.shortest)
            highest = blocks[x + 1].end - (blocks[x + 1].kind == .free ? 0 : Self.shortest)
            if let piece = slices.last(where: { $0.end == minute }) { lowest = max(lowest, piece.start + short(piece)) }
            if let piece = slices.first(where: { $0.start == minute }) { highest = min(highest, piece.end - short(piece)) }
        case let .itemStart(id):
            guard let item = item(id) else { break }
            lowest = slices.last { $0.end == item.start }?.start ?? 0
            highest = item.end - Self.shortest
        case let .itemEnd(id):
            guard let item = item(id) else { break }
            lowest = item.start + Self.shortest
            highest = slices.first { $0.start == item.end }?.end ?? 1440
        case let .items(x, y):
            guard let ending = item(x), let starting = item(y) else { break }
            lowest = ending.start + Self.shortest
            highest = starting.end - Self.shortest
        }
        return lowest...max(lowest, highest)
    }

    /// Moves a knob's edge to `minute`, snapped to 5 minutes and kept in `range`.
    mutating func move(_ edge: DayKnob.Edge, to minute: Int, within range: ClosedRange<Int>) -> Move {
        let snapped = Int((Double(minute) / Double(Self.snap)).rounded()) * Self.snap
        let clamped = min(max(snapped, range.lowerBound), range.upperBound)
        switch edge {
        case let .blocks(x):
            blocks[x].end = clamped
            blocks[x + 1].start = clamped
        case let .itemStart(id):
            setItem(id) { $0.start = clamped }
        case let .itemEnd(id):
            setItem(id) { $0.end = clamped }
        case let .items(x, y):
            setItem(x) { $0.end = clamped }
            setItem(y) { $0.start = clamped }
        }
        return clamped == snapped ? .moved(clamped) : .stopped(clamped)
    }

    /// After an item's edge moved: a template piece under 15 minutes left beside it goes under the
    /// item ("No forced gaps"), so the item edge meets the next knob.
    mutating func settleItem(_ id: ScheduleItem.ID) {
        guard let item = item(id) else { return }
        let slices = self.slices
        let isShortBlock = { (slice: ClockSlice) in !slice.isItem && slice.end - slice.start < Self.shortest }
        if let piece = slices.last(where: { $0.end == item.start }), isShortBlock(piece) {
            setItem(id) { $0.start = piece.start }
        }
        if let piece = slices.first(where: { $0.start == item.end }), isShortBlock(piece) {
            setItem(id) { $0.end = piece.end }
        }
    }

    /// A typed start time for an item: its knob's rules, or the day's edge when nothing touches it.
    mutating func setItemStart(_ id: ScheduleItem.ID, to minute: Int) -> Move {
        guard let item = item(id), !item.isAnchored else { return .noKnob }
        let edge = clockKnobs.first { knob in
            switch knob.edge {
            case let .itemStart(start), let .items(_, start): start == id
            default: false
            }
        }?.edge ?? .itemStart(id)
        beginChange()
        let move = move(edge, to: minute, within: range(of: edge))
        settleItem(id)
        return move
    }

    /// A typed end time for an item.
    mutating func setItemEnd(_ id: ScheduleItem.ID, to minute: Int) -> Move {
        guard let item = item(id), !item.isAnchored else { return .noKnob }
        let edge = clockKnobs.first { knob in
            switch knob.edge {
            case let .itemEnd(end), let .items(end, _): end == id
            default: false
            }
        }?.edge ?? .itemEnd(id)
        beginChange()
        let move = move(edge, to: minute, within: range(of: edge))
        settleItem(id)
        return move
    }

    /// Spec "Add between two slices": 30 minutes from the knob into the slice after it, or up to the
    /// knob from the slice before it when the one after is shorter than 45 minutes. nil when neither
    /// has room.
    func addSpan(atKnob index: Int) -> Range<Int>? {
        let knobs = clockKnobs, slices = self.slices
        guard knobs.indices.contains(index) else { return nil }
        let minute = knobs[index].minute
        let room = Self.between + Self.shortest
        if let after = slices.first(where: { $0.start == minute }), after.end - after.start >= room {
            return minute..<(minute + Self.between)
        }
        if let before = slices.last(where: { $0.end == minute }), before.end - before.start >= room {
            return (minute - Self.between)..<minute
        }
        return nil
    }

    /// Spec "Tapping +" on free paper: the first hour of the free span (all of it when it is an hour
    /// or less); a leftover shorter than 15 minutes joins the new slice.
    func addSpan(inFreeAt minute: Int) -> Range<Int>? {
        guard let free = slices.first(where: { $0.kind == .free && $0.start <= minute && minute < $0.end }) else {
            return nil
        }
        var end = min(free.end, free.start + Self.firstHour)
        if free.end - end < Self.shortest { end = free.end }
        return free.start..<end
    }

    /// Board G1f: a new item from the clock's "+", once its picture is picked. One change for Undo.
    mutating func add(_ item: ClockItem) {
        beginChange()
        items.append(item)
    }

    /// A new item's picture, name or kind of repeat changed while its card is open: part of the
    /// change that added it, so Undo takes the whole new item back in one step.
    mutating func restyleItem(_ id: ScheduleItem.ID, title: String, iconName: String, isRepeating: Bool) {
        setItem(id) {
            $0.title = title
            $0.iconName = iconName
            $0.isRepeating = isRepeating
        }
    }

    /// "Skip this day" / "Bring back" on an item (one change for Undo).
    mutating func setItemSkipped(_ id: ScheduleItem.ID, _ skipped: Bool) {
        guard let item = item(id), item.isSkipped != skipped else { return }
        beginChange()
        setItem(id) { $0.isSkipped = skipped }
    }

    /// "Remove" on an item: off the clock until Undo; Save ends its series or deletes it. A new item
    /// that was never saved simply goes.
    mutating func removeItem(_ id: ScheduleItem.ID) {
        guard let item = item(id), !item.isRemoved else { return }
        beginChange()
        if item.isNew {
            items.removeAll { $0.id == id }
        } else {
            setItem(id) { $0.isRemoved = true }
        }
    }

    private mutating func setItem(_ id: ScheduleItem.ID, _ change: (inout ClockItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[index])
    }
}


public extension TemplateEdit {
    /// School's slice on a school's hours (start at Arrive by, or the start), with the knob rules; a
    /// template without a School slice stays as it is (G4 saves, G7 change school).
    static func movingSchool(_ blocks: [RoutineBlock], to school: School) -> [RoutineBlock] {
        var edit = TemplateEdit(blocks: blocks)
        if let index = edit.blocks.firstIndex(where: { $0.kind == .school }) {
            _ = edit.setStart(ofBlock: index, to: school.arriveBy ?? school.start)
        }
        if let index = edit.blocks.firstIndex(where: { $0.kind == .school }) {
            _ = edit.setEnd(ofBlock: index, to: school.end)
        }
        return edit.blocks
    }

    /// Spec "Where the kid goes changes": the weekday template for the kid's new place. A school or
    /// preschool moves the School slice to its hours (and names it "School" or "Preschool"); a kid
    /// with no School slice yet gets one over those hours, cutting into what was there. At home
    /// (`nil`) turns the School slice into free time.
    static func placingSchool(_ blocks: [RoutineBlock], school: School?) -> [RoutineBlock] {
        guard let school else {
            let rest = blocks.map { block -> RoutineBlock in
                guard block.kind == .school else { return block }
                return free(from: block.start, to: block.end)
            }
            return mergingFree(rest)
        }
        let title = school.isPreschool ? L10n.tr("starter.preschool") : L10n.tr("starter.school")
        let icon = school.isPreschool ? "playground" : "actSchool"
        if blocks.contains(where: { $0.kind == .school }) {
            return movingSchool(blocks, to: school).map { block in
                guard block.kind == .school else { return block }
                var named = block
                named.title = title
                named.iconName = icon
                return named
            }
        }
        let start = school.arriveBy ?? school.start, end = school.end
        guard start < end else { return blocks }
        var kept: [RoutineBlock] = []
        for block in blocks {
            if block.end <= start || block.start >= end { kept.append(block); continue }
            if block.start < start {
                var head = block
                head.end = start
                if head.end - head.start >= shortest || head.kind == .free { kept.append(head) }
            }
            if block.end > end {
                var tail = block
                tail.start = end
                if tail.end - tail.start >= shortest || tail.kind == .free { kept.append(tail) }
            }
        }
        kept.append(RoutineBlock(title: title, iconName: icon, kind: .school, start: start, end: end, isLocked: true))
        return TemplateEdit(blocks: kept).blocks
    }

    /// Free slices that touch become one.
    private static func mergingFree(_ blocks: [RoutineBlock]) -> [RoutineBlock] {
        var out: [RoutineBlock] = []
        for block in blocks.sorted(by: { $0.start < $1.start }) {
            if block.kind == .free, let last = out.last, last.kind == .free, last.end == block.start {
                out[out.count - 1].end = block.end
            } else {
                out.append(block)
            }
        }
        return out
    }
}
