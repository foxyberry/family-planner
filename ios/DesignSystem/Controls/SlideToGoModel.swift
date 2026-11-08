/// Decisions behind `SlideToGo`, kept out of the view so they can be tested.
public struct SlideToGoModel: Equatable, Sendable {
    public enum Phase: Equatable, Sendable {
        case locked(remaining: Int)
        case idle
        case dragging(progress: Double)
        case done
    }

    /// How far the handle must travel (0...1) for a release to count.
    public static let completeThreshold = 0.9

    public var phase: Phase

    public init(phase: Phase) {
        self.phase = phase
    }

    /// Ignored while locked or done; otherwise clamps to 0...1.
    public mutating func dragChanged(progress: Double) {
        switch phase {
        case .locked, .done: return
        case .idle, .dragging: phase = .dragging(progress: min(max(progress, 0), 1))
        }
    }

    /// Completes at or past the threshold (returns true), otherwise snaps back to idle.
    public mutating func dragEnded() -> Bool {
        guard case let .dragging(progress) = phase else { return false }
        if progress >= Self.completeThreshold {
            phase = .done
            return true
        }
        phase = .idle
        return false
    }

    /// From done, dragging the knob back (spec "After the slide"): `progress` 1 → 0.
    public mutating func undoDragChanged(progress: Double) {
        guard phase == .done || isUndoing else { return }
        phase = .dragging(progress: min(max(progress, 0), 1))
        isUndoing = true
    }

    /// Past the middle the slide lets go (returns true: undo); otherwise it springs back to done.
    public mutating func undoDragEnded() -> Bool {
        guard isUndoing, case let .dragging(progress) = phase else { return false }
        isUndoing = false
        if progress < Self.undoThreshold {
            phase = .idle
            return true
        }
        phase = .done
        return false
    }

    /// Dragging back past the middle undoes.
    public static let undoThreshold = 0.5
    /// A drag that started from done.
    public var isUndoing = false
}
