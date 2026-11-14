import Foundation
import Strings

/// Editing one day template on the C6 clock (spec "C6 · Our day", Drag rules). Every boundary between
/// two slices is a knob; moving it moves the end of one slice and the start of the next together.
/// Times snap to 5 minutes, no slice is shorter than 15 minutes and knobs never cross. School's edges
/// move like any other (layout v37). There are no forced gaps: slices may touch exactly, and free
/// time shorter than 15 minutes never stays (it joins the slice beside it). The two sleep halves
/// meet at midnight, which has no knob.
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

    public private(set) var blocks: [RoutineBlock]
    private var history: [[RoutineBlock]] = []
    /// Changes taken back by Undo since the last change, for Redo (spec "Grown-up mode", G1).
    private var future: [[RoutineBlock]] = []

    /// A new slice put between two slices (board G1e) is this long.
    public static let between = 30

    public init(blocks: [RoutineBlock]) {
        self.blocks = blocks.sorted { $0.start < $1.start }
        closeShortGaps()
    }

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
        history.append(blocks)
        future.removeAll()
    }

    /// Moves a knob while dragging. Free time beside it may shrink to nothing here; `closeShortGaps`
    /// (on release, after a typed time) folds what is left under 15 minutes into the moved slice.
    public mutating func moveKnob(_ index: Int, to minute: Int) -> Move {
        let knob = knobs[index]
        let snapped = Int((Double(minute) / Double(Self.snap)).rounded()) * Self.snap
        let lowest = blocks[knob.before].start + (blocks[knob.before].kind == .free ? 0 : Self.shortest)
        let highest = blocks[knob.after].end - (blocks[knob.after].kind == .free ? 0 : Self.shortest)
        let clamped = min(max(snapped, lowest), highest)
        blocks[knob.before].end = clamped
        blocks[knob.after].start = clamped
        return clamped == snapped ? .moved(clamped) : .stopped(clamped)
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

    /// Board G1e: a new 30-minute slice at a shared knob, as free time for the new-slice card to fill.
    /// It starts at the knob and is taken from the slice after it; when that one is shorter than 45
    /// minutes it ends at the knob and is taken from the slice before it. Nil when neither has room.
    public mutating func insertBetween(knob index: Int) -> Int? {
        guard knobs.indices.contains(index) else { return nil }
        let knob = knobs[index]
        let room = Self.between + Self.shortest
        let after = blocks[knob.after], before = blocks[knob.before]
        if after.end - after.start >= room {
            beginChange()
            blocks[knob.after].start = knob.minute + Self.between
            blocks.insert(Self.free(from: knob.minute, to: knob.minute + Self.between), at: knob.after)
            return knob.after
        }
        if before.end - before.start >= room {
            beginChange()
            blocks[knob.before].end = knob.minute - Self.between
            blocks.insert(Self.free(from: knob.minute - Self.between, to: knob.minute), at: knob.after)
            return knob.after
        }
        return nil
    }

    /// "Make this free time": blank paper over the same span, joined with free time right before or
    /// after it, so the day can lose slices as well as gain them. School (`isLocked`) cannot be made
    /// free. Returns the free slice's index.
    @discardableResult
    public mutating func makeFree(_ block: Int) -> Int {
        guard !blocks[block].isLocked, blocks[block].kind != .free else { return block }
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

    /// A new slice at the start of a free slice, `length` minutes long (one hour by default); the
    /// rest stays free when it is at least 15 minutes, so more slices can go in after it (user,
    /// 2026-11-09: the number of slices is not fixed). Shorter free time is filled whole.
    public mutating func fill(_ block: Int, title: String, iconName: String, kind: SlotKind, length: Int = 60) {
        guard blocks[block].kind == .free else { return }
        beginChange()
        let free = blocks[block]
        var end = min(free.end, free.start + max(length, Self.shortest))
        if free.end - end < Self.shortest { end = free.end }
        blocks[block] = RoutineBlock(title: title, iconName: iconName, kind: kind, start: free.start, end: end)
        if end < free.end {
            blocks.insert(Self.free(from: end, to: free.end), at: block + 1)
        }
    }

    /// Board G1f: a new slice's picture, kind or name changed while its card is open. It belongs to
    /// the change that made the slice, so Undo takes the whole new slice back in one step.
    public mutating func restyle(_ block: Int, title: String, iconName: String, kind: SlotKind) {
        guard blocks.indices.contains(block), blocks[block].kind != .free else { return }
        blocks[block].title = title
        blocks[block].iconName = iconName
        blocks[block].kind = kind
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

    /// Takes back the last change (one finished drag, one typed time, one "Make this free time").
    public mutating func undo() {
        guard let last = history.popLast() else { return }
        future.append(blocks)
        blocks = last
    }

    /// Drops the last change without a Redo step (a G1e slice closed without being added).
    public mutating func dropLastChange() {
        guard let last = history.popLast() else { return }
        blocks = last
    }

    /// Puts back the change Undo took back last.
    public mutating func redo() {
        guard let next = future.popLast() else { return }
        history.append(blocks)
        blocks = next
    }

    /// The blocks as they were at the last save (or when the edit began).
    public var savedBlocks: [RoutineBlock] { history.first ?? blocks }

    /// The first slice that differs from the saved blocks (board G1d names it), skipping free time.
    public var firstChange: RoutineBlock? {
        let saved = savedBlocks
        return blocks.enumerated().first { index, block in
            block.kind != .free && (index >= saved.count || saved[index] != block)
        }?.element
    }

    /// After a save the edit starts again from the saved blocks: nothing to undo or redo.
    public mutating func markSaved() {
        history.removeAll()
        future.removeAll()
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
}
