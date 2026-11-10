import Foundation
import Strings

/// Editing one day template on the C6 clock (spec "C6 · Our day", Drag rules). Every boundary between
/// two slices is a knob; moving it moves the end of one slice and the start of the next together.
/// Times snap to 5 minutes, no slice is shorter than 15 minutes, knobs never cross, and the edges of
/// a locked slice (school) do not move. The two sleep halves meet at midnight, which has no knob.
public struct TemplateEdit: Equatable, Sendable {
    public struct Knob: Equatable, Sendable {
        public var minute: Int
        /// The slice that ends at this knob and the one that starts there.
        public var before: Int
        public var after: Int
        public var isLocked: Bool
    }

    /// What a move did: moved to the snapped minute, stopped at a limit (bump haptic), or refused.
    public enum Move: Equatable, Sendable {
        case moved(Int)
        case stopped(Int)
        case locked
    }

    public static let snap = 5
    public static let shortest = 15

    public private(set) var blocks: [RoutineBlock]
    private var history: [[RoutineBlock]] = []
    /// Changes taken back by Undo since the last change, for Redo (spec "Grown-up mode", G1).
    private var future: [[RoutineBlock]] = []

    public init(blocks: [RoutineBlock]) {
        self.blocks = blocks.sorted { $0.start < $1.start }
    }

    public var knobs: [Knob] {
        blocks.indices.dropLast().compactMap { i in
            guard blocks[i].end == blocks[i + 1].start else { return nil }
            return Knob(minute: blocks[i].end, before: i, after: i + 1,
                        isLocked: blocks[i].isLocked || blocks[i + 1].isLocked)
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

    public mutating func moveKnob(_ index: Int, to minute: Int) -> Move {
        let knob = knobs[index]
        guard !knob.isLocked else { return .locked }
        let snapped = Int((Double(minute) / Double(Self.snap)).rounded()) * Self.snap
        let lowest = blocks[knob.before].start + Self.shortest
        let highest = blocks[knob.after].end - Self.shortest
        let clamped = min(max(snapped, lowest), highest)
        blocks[knob.before].end = clamped
        blocks[knob.after].start = clamped
        return clamped == snapped ? .moved(clamped) : .stopped(clamped)
    }

    /// A typed start time: moves the knob before the slice, with the same rules.
    public mutating func setStart(ofBlock block: Int, to minute: Int) -> Move {
        guard let index = knobs.firstIndex(where: { $0.after == block }) else { return .locked }
        if knobs[index].isLocked { return .locked }
        beginChange()
        return moveKnob(index, to: minute)
    }

    /// A typed end time: moves the knob after the slice, with the same rules.
    public mutating func setEnd(ofBlock block: Int, to minute: Int) -> Move {
        guard let index = knobs.firstIndex(where: { $0.before == block }) else { return .locked }
        if knobs[index].isLocked { return .locked }
        beginChange()
        return moveKnob(index, to: minute)
    }

    /// "Make this free time": blank paper over the same span, joined with free time right before or
    /// after it, so the day can lose slices as well as gain them. A locked slice stays. Returns the
    /// free slice's index.
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

    private static func free(from start: Int, to end: Int) -> RoutineBlock {
        RoutineBlock(title: L10n.tr("home.hub.free"), iconName: "", kind: .free, start: start, end: end)
    }

    /// Takes back the last change (one finished drag, one typed time, one "Make this free time").
    public mutating func undo() {
        guard let last = history.popLast() else { return }
        future.append(blocks)
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

    /// The caption under the slice card: "Shower now starts at 7:30 pm and is 30 min."
    public func effect(ofKnob index: Int) -> String {
        let next = blocks[knobs[index].after]
        return L10n.tr("day.effect", next.title, TimeText.withPeriod(next.start), TimeText.duration(next.end - next.start))
    }
}
