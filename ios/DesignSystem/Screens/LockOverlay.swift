import CrayonKit
import SwiftUI

/// The grown-up lock over the home screen (board C0). Face ID only: there is no passcode button.
/// An iPad without Face ID set up offers "Enter", since the 2-second hold already chose grown-up screens.
public struct LockOverlay: View {
    /// What the lock is doing; the caller turns it into words.
    public enum State: Equatable, Sendable {
        case scanning
        case notRecognised
        case notAvailable(touchID: Bool)
        case lockedOut
    }

    private let title: String
    private let message: String
    private let primary: String?
    private let cancel: String
    private let onPrimary: () -> Void
    private let onCancel: () -> Void

    /// Words from the caller. `primary`: the first button ("Try again", "Enter"); nil shows only
    /// `cancel`.
    public init(title: String, message: String, primary: String?, cancel: String,
                onPrimary: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.title = title
        self.message = message
        self.primary = primary
        self.cancel = cancel
        self.onPrimary = onPrimary
        self.onCancel = onCancel
    }

    public var body: some View {
        ZStack {
            CrayonColor.pictureMarker.opacity(0.6).ignoresSafeArea()
            // Spec "Lock": no line above the card for any entry (hold, pencil, link); the title is enough.
            VStack(spacing: Spacing.m) {
                PaperCard(seed: CrayonStyle.Seed.card + 11) {
                    VStack(alignment: .leading, spacing: Spacing.m) {
                        HStack(spacing: Spacing.s) {
                            Image(systemName: "lock.fill").font(.system(size: 40, weight: .bold))
                            Text(title).crayonType(.title)
                        }
                        .foregroundStyle(CrayonColor.ink)
                        Text(message).crayonType(.body).foregroundStyle(CrayonColor.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: Spacing.m) {
                            if let primary { CardButton(primary, action: onPrimary) }
                            CardButton(cancel, action: onCancel)
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
