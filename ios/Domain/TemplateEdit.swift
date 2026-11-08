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

    /// Call once when a drag starts (or before a typed change), so undo steps back a whole change.
    public mutating func beginChange() {
        history.append(blocks)
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

    /// "Make this free time": blank paper over the same span. A locked slice stays.
    public mutating func makeFree(_ block: Int) {
        guard !blocks[block].isLocked, blocks[block].kind != .free else { return }
        beginChange()
        blocks[block] = RoutineBlock(title: L10n.tr("home.hub.free"), iconName: "", kind: .free,
                                     start: blocks[block].start, end: blocks[block].end)
    }

    /// Fills a free slice with a new one over exactly its span.
    public mutating func fill(_ block: Int, title: String, iconName: String, kind: SlotKind) {
        guard blocks[block].kind == .free else { return }
        beginChange()
        blocks[block] = RoutineBlock(title: title, iconName: iconName, kind: kind,
                                     start: blocks[block].start, end: blocks[block].end)
    }

    public mutating func undo() {
        if let last = history.popLast() { blocks = last }
    }

    /// After a save the edit starts again from the saved blocks.
    public mutating func markSaved() {
        history.removeAll()
    }

    /// The caption under the slice card: "Shower now starts at 7:30 pm and is 30 min."
    public func effect(ofKnob index: Int) -> String {
        let next = blocks[knobs[index].after]
        return L10n.tr("day.effect", next.title, TimeText.withPeriod(next.start), TimeText.duration(next.end - next.start))
    }
}
