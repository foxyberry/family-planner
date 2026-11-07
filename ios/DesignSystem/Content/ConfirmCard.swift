import CrayonKit
import SwiftUI

/// A small card that asks before something is lost ("Leave without adding?", "Remove Swimming?").
/// The destructive choice is in `lateText`. Place it next to the control that opened it.
public struct ConfirmCard: View {
    private let title: String
    private let message: String?
    private let cancel: String
    private let confirm: String
    private let isDestructive: Bool
    private let onCancel: () -> Void
    private let onConfirm: () -> Void

    public init(title: String, message: String?, cancel: String, confirm: String, isDestructive: Bool,
                onCancel: @escaping () -> Void, onConfirm: @escaping () -> Void) {
        self.title = title
        self.message = message
        self.cancel = cancel
        self.confirm = confirm
        self.isDestructive = isDestructive
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    public var body: some View {
        PaperCard(seed: CrayonStyle.Seed.card + 7) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text(title).crayonType(.head).foregroundStyle(CrayonColor.ink)
                if let message {
                    Text(message).crayonType(.body).foregroundStyle(CrayonColor.softText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: Spacing.m) {
                    CardButton(cancel, action: onCancel)
                    CardButton(confirm, isDestructive: isDestructive, action: onConfirm)
                }
            }
        }
        .frame(width: 520)
    }
}

/// The 240 × 72 paper buttons of confirm cards and the grown-up lock (boards C0, E5).
struct CardButton: View {
    private let title: String
    private let isDestructive: Bool
    private let action: () -> Void

    init(_ title: String, isDestructive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isDestructive = isDestructive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .crayonType(isDestructive ? .head : .body)
                .foregroundStyle(isDestructive ? CrayonColor.lateText : CrayonColor.ink)
                .lineLimit(1)
                .frame(width: 240, height: 72)
                .crayonBackground(.capsule, fill: CrayonStyle.paper, seed: CrayonStyle.Seed.tabs + 9)
        }
        .buttonStyle(.plain)
    }
}
