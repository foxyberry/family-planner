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
    private let cancel: String
    private let confirm: String
    private let isDestructive: Bool
    private let onCancel: () -> Void
    private let onConfirm: () -> Void

    public init(title: String, message: String?, messageGlyph: MarkerGlyph? = nil, cancel: String, confirm: String,
                isDestructive: Bool, onCancel: @escaping () -> Void,
                onConfirm: @escaping () -> Void) {
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

    /// Spec "Layout balance": an overlay card pads 32 from its drawn edge to the content's drawn
    /// boxes. Its content starts on the content line (drawn + 32, where a framed button's frame also
    /// sits) and ends on text (the cancel choice); its last row is the buttons' frames.
    static let padding = EdgeInsets(top: Spacing.card + CrayonPart.inset, leading: Spacing.card + CrayonPart.inset,
                                    bottom: Spacing.card, trailing: Spacing.card + CrayonPart.inset)
    /// Board C3x: 40 from the main button's frame to the cancel text.
    static let buttonGap: CGFloat = Spacing.l
    /// Spec "Part floors" (design session, layout v56): drawn width max(520 s, content + 64), frame
    /// one inset wider each side. The content is the buttons row (button frame, gap, cancel text);
    /// the title and message wrap inside. C3x "Leave" / "Keep editing" gives 541 on the 13".
    public static func width(sizing: Sizing, cancel: String) -> CGFloat {
        let content = CardButton.width + buttonGap + CrayonType.body.width(cancel, sizing: sizing, bold: true)
        return ceil(max(520 * sizing.s, content + 2 * Spacing.card) + 2 * CrayonPart.inset)
    }

    public var body: some View {
        PaperCard(seed: CrayonStyle.Seed.card + 7, padding: Self.padding) {
            // Spec "Layout balance": the text block, then the buttons row 24 below between drawn edges.
            VStack(alignment: .leading, spacing: sizing.formRowGap - CrayonPart.inset) {
                VStack(alignment: .leading, spacing: Spacing.s) {
                    Text(title).crayonType(.head).foregroundStyle(CrayonColor.ink)
                    if let message, let messageGlyph {
                        GlyphText(message, glyph: messageGlyph, type: .body, color: CrayonColor.softText)
                    } else if let message {
                        Text(message).crayonType(.body).foregroundStyle(CrayonColor.softText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                // The main choice first (design session, 2026-11-14): an InkButton, or the lateText
                // button when it destroys something; the other choice after it as plain text.
                HStack(spacing: Self.buttonGap) {
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
            // The paper is the card's full width (`width`); only its height hugs the content.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: Self.width(sizing: sizing, cancel: cancel))
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
