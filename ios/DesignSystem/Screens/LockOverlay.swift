import CrayonKit
import Strings
import SwiftUI

/// The grown-up lock over the home screen (board C0). Face ID only: there is no passcode button.
/// An iPad without Face ID set up offers "Enter", since the 2-second hold already chose grown-up screens.
public struct LockOverlay: View {
    public enum State: Equatable, Sendable {
        case scanning
        case notRecognised
        case notAvailable(touchID: Bool)
        case lockedOut

        var message: String {
            switch self {
            case .scanning: L10n.tr("lock.scanning")
            case .notRecognised: L10n.tr("lock.unrecognised")
            case let .notAvailable(touchID): touchID ? L10n.tr("lock.off.touch_id") : L10n.tr("lock.off.face_id")
            case .lockedOut: L10n.tr("lock.locked_out")
            }
        }

        /// The first button, or `nil` when the state offers only one.
        var primary: String? {
            switch self {
            case .scanning, .lockedOut: nil
            case .notRecognised: L10n.tr("lock.retry")
            case .notAvailable: L10n.tr("lock.enter")
            }
        }

        var cancel: String { self == .lockedOut ? L10n.tr("lock.ok") : L10n.tr("lock.cancel") }
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
                Text(L10n.tr("lock.held")).crayonType(.body).foregroundStyle(CrayonColor.nightText)
                PaperCard(seed: CrayonStyle.Seed.card + 11) {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        HStack(spacing: Spacing.s) {
                            Image(systemName: "lock.fill").font(.system(size: 40, weight: .bold))
                            Text(L10n.tr("lock.title")).crayonType(.title)
                        }
                        .foregroundStyle(CrayonColor.ink)
                        Text(state.message).crayonType(.body).foregroundStyle(CrayonColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: Spacing.m) {
                            if let primary = state.primary { CardButton(primary, action: onPrimary) }
                            CardButton(state.cancel, action: onCancel)
                        }
                    }
                    // Board C0: padding 40 × 64, gap 24.
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.l)
                }
                .frame(width: 818)
            }
        }
    }
}
