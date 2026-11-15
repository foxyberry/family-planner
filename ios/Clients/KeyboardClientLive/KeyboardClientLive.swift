import KeyboardClient
import UIKit

extension KeyboardClient {
    /// UIKit's keyboard notifications. `keyboardWillChangeFrame` also fires for floating and split
    /// keyboards (they send no show / hide), so it is the one source; the frame is converted from
    /// screen space into the app window, which may not sit at the screen's origin.
    public static let live = Self(changes: {
        AsyncStream { continuation in
            let center = NotificationCenter.default
            let names = [UIResponder.keyboardWillChangeFrameNotification, UIResponder.keyboardWillHideNotification]
            let tokens = names.map { name in
                center.addObserver(forName: name, object: nil, queue: .main) { note in
                    let duration = (note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
                    let screenFrame = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect) ?? .zero
                    let top: CGFloat? = MainActor.assumeIsolated {
                        guard name != UIResponder.keyboardWillHideNotification,
                              let window = UIApplication.shared.connectedScenes
                                  .compactMap({ $0 as? UIWindowScene })
                                  .flatMap(\.windows)
                                  .first(where: \.isKeyWindow)
                        else { return nil }
                        let frame = window.convert(screenFrame, from: window.screen.coordinateSpace)
                        return KeyboardRule.keyboardTop(endFrame: frame, window: window.bounds)
                    }
                    continuation.yield(KeyboardChange(top: top, duration: duration))
                }
            }
            let observers = Observers(tokens)
            continuation.onTermination = { _ in observers.remove(from: center) }
        }
    })
}

/// The notification observers, removed when the stream ends (the tokens are not Sendable).
private final class Observers: @unchecked Sendable {
    private let tokens: [any NSObjectProtocol]
    init(_ tokens: [any NSObjectProtocol]) { self.tokens = tokens }
    func remove(from center: NotificationCenter) { tokens.forEach { center.removeObserver($0) } }
}
