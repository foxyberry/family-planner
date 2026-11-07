import CrayonKit
import SwiftUI

/// The grown-up lock over the home screen (board C0). Face ID only: there is no passcode button.
public struct LockOverlay: View {
    public enum State: Equatable, Sendable {
        case scanning
        case notRecognised
        case notAvailable(touchID: Bool)
        case lockedOut

        var message: String {
            switch self {
            case .scanning: "Look at the iPad to unlock."
            case .notRecognised: "That didn't unlock."
            case let .notAvailable(touchID):
                "\(touchID ? "Touch ID" : "Face ID") is off on this iPad. Turn it on in Settings to open grown-up screens."
            case .lockedOut: "Too many tries. Unlock the iPad with its passcode, then try again."
            }
        }

        /// The first button, or `nil` when the state offers only one.
        var primary: String? {
            switch self {
            case .scanning, .lockedOut: nil
            case .notRecognised: "Try again"
            case .notAvailable: "Open Settings"
            }
        }

        var cancel: String { self == .lockedOut ? "OK" : "Cancel" }
    }

    private let state: State
    private let onPrimary: () -> Void
    private let onCancel: () -> Void

    public init(state: State, onPrimary: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.state = state
        self.onPrimary = onPrimary
        self.onCancel = onCancel
    }

    public var body: some View {
        ZStack {
            CrayonColor.marker.opacity(0.6).ignoresSafeArea()
            VStack(spacing: Spacing.m) {
                Text("Held the clock for 2 seconds").crayonType(.body).foregroundStyle(CrayonColor.nightText)
                PaperCard(seed: CrayonStyle.Seed.card + 11) {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack(spacing: Spacing.s) {
                            Image(systemName: "lock.fill").font(.system(size: 40, weight: .bold))
                            Text("Grown-ups only").crayonType(.title)
                        }
                        .foregroundStyle(CrayonColor.ink)
                        Text(state.message).crayonType(.body).foregroundStyle(CrayonColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: Spacing.m) {
                            if let primary = state.primary { CardButton(primary, action: onPrimary) }
                            CardButton(state.cancel, action: onCancel)
                        }
                    }
                    .padding(.horizontal, Spacing.l)
                    .padding(.vertical, Spacing.m)
                }
                .frame(width: 818)
            }
        }
    }
}
