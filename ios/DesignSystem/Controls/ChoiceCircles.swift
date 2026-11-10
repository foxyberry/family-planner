import CrayonKit
import KitArt
import SwiftUI

/// A row of 88 picture circles on a 112 pitch with a caption (up to 112 wide, so "Backpack" stays one
/// word) under each; picked ones get a 104 pick-blue ring and a bold caption (boards C3g "Going",
/// F1–F4). A choice without a picture shows its `word` inside (Bring's "More") or "–".
public struct ChoiceCircles: View {
    public struct Choice: Equatable, Sendable, Identifiable {
        public var id: String
        public var picture: KitSlot?
        public var caption: String
        public var isPicked: Bool
        /// A word inside the circle instead of a picture ("More"); its caption is empty.
        public var word: String?

        public init(id: String, picture: KitSlot?, caption: String, isPicked: Bool, word: String? = nil) {
            self.id = id
            self.picture = picture
            self.caption = caption
            self.isPicked = isPicked
            self.word = word
        }
    }

    private let choices: [Choice]
    private let onPick: (String) -> Void

    public init(_ choices: [Choice], onPick: @escaping (String) -> Void) {
        self.choices = choices
        self.onPick = onPick
    }

    public var body: some View {
        // Each choice is 112 wide (its caption's width), so the circles sit on the 112 pitch.
        HStack(alignment: .top, spacing: 0) {
            ForEach(choices) { choice in
                Button { onPick(choice.id) } label: {
                    VStack(spacing: Spacing.xxs) {
                        ZStack {
                            if let picture = choice.picture {
                                KitIcon(picture, size: 64)
                            } else if let word = choice.word {
                                Text(word).crayonType(.caption, bold: true).foregroundStyle(CrayonColor.ink)
                            } else {
                                Text(verbatim: "–").crayonType(.title).foregroundStyle(CrayonColor.softText)
                            }
                        }
                        .frame(width: 88, height: 88)
                        .partBackground(.circle, fill: CrayonStyle.paper, seed: CrayonStyle.Seed.iconPicker)
                        .overlay {
                            if choice.isPicked {
                                Circle().stroke(CrayonColor.pickBlue, lineWidth: 5).frame(width: 104, height: 104)
                            }
                        }
                        Text(choice.caption).crayonType(.caption, bold: choice.isPicked).foregroundStyle(CrayonColor.ink)
                            .multilineTextAlignment(.center)
                            // A one-word caption never breaks inside the word ("Backpack"); it may
                            // run a few points past its 112.
                            .fixedSize(horizontal: !choice.caption.contains(" "), vertical: true) // copy-ok: a space
                            .frame(width: 112)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(choice.word ?? choice.caption)
                .accessibilityAddTraits(choice.isPicked ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}
