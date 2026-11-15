import ComposableArchitecture
import CoreGraphics

/// Spec "Keyboard" (user, 2026-11-15): one injected dependency decides "keyboard up" for every
/// screen. The keyboard is up only when the on-screen keyboard is docked along the window's full width
/// and covers its bottom by more than 100 pt; a floating or split keyboard, or a hardware keyboard
/// with only its shortcut bar, counts as no keyboard.
public struct KeyboardChange: Equatable, Sendable {
    /// The keyboard's top edge in window points while it is up; nil when it is not.
    public var top: CGFloat?
    /// The keyboard's own animation, so the card and button move with it.
    public var duration: Double

    public init(top: CGFloat?, duration: Double) {
        self.top = top
        self.duration = duration
    }
}

public enum KeyboardRule {
    /// The smallest covered height that counts as a keyboard (a hardware keyboard's bar is ~55).
    public static let minimumCover: CGFloat = 100

    /// The keyboard's top edge in window points, or nil when the keyboard does not count as up.
    /// `endFrame` is the keyboard's end frame and `window` the app window, both in one space.
    public static func keyboardTop(endFrame: CGRect, window: CGRect) -> CGFloat? {
        guard !endFrame.isEmpty, !window.isEmpty else { return nil }
        // Docked: as wide as the window and down to its bottom edge (floating and split are not).
        let fullWidth = endFrame.minX <= window.minX + 1 && endFrame.maxX >= window.maxX - 1
        let atBottom = endFrame.maxY >= window.maxY - 1
        let covered = window.maxY - max(endFrame.minY, window.minY)
        guard fullWidth, atBottom, covered > minimumCover else { return nil }
        return endFrame.minY - window.minY
    }
}

@DependencyClient
public struct KeyboardClient: Sendable {
    /// Every keyboard change from now on (the live value starts with the current state).
    public var changes: @Sendable () -> AsyncStream<KeyboardChange> = { .finished }
}

extension KeyboardClient: TestDependencyKey {
    /// Tests: no keyboard unless a test sends changes (screens rarely care).
    public static let testValue = Self(changes: { .finished })
    /// Previews: no keyboard.
    public static let previewValue = Self(changes: { .finished })
}

extension DependencyValues {
    public var keyboard: KeyboardClient {
        get { self[KeyboardClient.self] }
        set { self[KeyboardClient.self] = newValue }
    }
}
