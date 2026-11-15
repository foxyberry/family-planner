import CrayonKit
import SwiftUI

/// A small card that asks before something is lost ("Leave without adding?", "Remove Swimming?",
/// G1d "Save the changes?"). Every confirm in the app is this one part (spec "ConfirmCard"). The
/// destructive choice is in `lateText`. A message can draw one marker glyph inline at text size
/// (`messageGlyph`, at the message's `%@`), since Playpen Sans has no arrows.
/// Place it next to the control that opened it.
public struct ConfirmCard: View {
    private let title: String
    private let message: String?
    private let messageGlyph: MarkerGlyph?
    private let width: CGFloat?
    private let cancel: String
    private let confirm: String
    private let isDestructive: Bool
    private let onCancel: () -> Void
    private let onConfirm: () -> Void

    public init(title: String, message: String?, messageGlyph: MarkerGlyph? = nil, cancel: String, confirm: String,
                isDestructive: Bool, width: CGFloat? = nil, onCancel: @escaping () -> Void,
                onConfirm: @escaping () -> Void) {
        self.width = width
        self.title = title
        self.message = message
        self.messageGlyph = messageGlyph
        self.cancel = cancel
        self.confirm = confirm
        self.isDestructive = isDestructive
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    @Environment(\.sizing) private var sizing

    /// Spec "Layout balance": an overlay card pads 32 from its drawn edge (text at the top and left,
    /// the buttons' frames at the bottom and right).
    static let padding = EdgeInsets(top: Spacing.card + CrayonPart.inset, leading: Spacing.card + CrayonPart.inset,
                                    bottom: Spacing.card, trailing: Spacing.card)
    /// Spec "Part floors": width max(520 s, its content + the padding); the content is the buttons
    /// row, and the title and message wrap inside.
    static func width(sizing: Sizing, cancel: String) -> CGFloat {
        let buttons = CardButton.width + Spacing.m + CrayonType.body.width(cancel, sizing: sizing, bold: true)
        return max(520 * sizing.s, ceil(buttons + padding.leading + padding.trailing))
    }

    public var body: some View {
        PaperCard(seed: CrayonStyle.Seed.card + 7, padding: Self.padding) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Text(title).crayonType(.head).foregroundStyle(CrayonColor.ink)
                if let message, let messageGlyph {
                    GlyphText(message, glyph: messageGlyph, type: .body, color: CrayonColor.softText)
                } else if let message {
                    Text(message).crayonType(.body).foregroundStyle(CrayonColor.softText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // The main choice first (design session, 2026-11-14): an InkButton, or the lateText
                // button when it destroys something; the other choice after it as plain text.
                HStack(spacing: Spacing.m) {
                    if isDestructive {
                        CardButton(confirm, isDestructive: true, action: onConfirm)
                    } else {
                        InkButton(confirm, height: 72, action: onConfirm).frame(width: CardButton.width)
                    }
                    Button(action: onCancel) {
                        Text(cancel).crayonType(.body, bold: true).foregroundStyle(CrayonColor.softText)
                            .lineLimit(1).fixedSize()
                            .frame(minHeight: 72)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            // The paper is the card's full width (board C3x: 560); only its height hugs the content.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: width ?? Self.width(sizing: sizing, cancel: cancel))
    }
}

/// The 240 × 72 paper buttons of confirm cards and the grown-up lock (boards C0, E5).
struct CardButton: View {
    static let width: CGFloat = 240
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
                .frame(width: Self.width, height: 72)
                .partBackground(.capsule, fill: CrayonStyle.paper, seed: CrayonStyle.Seed.tabs + 9)
        }
        .buttonStyle(.plain)
    }
}
