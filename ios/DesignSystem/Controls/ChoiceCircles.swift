import CrayonKit
import KitArt
import SwiftUI

/// A row of 88 picture circles with a caption under each, one of them picked (pick-blue ring and a
/// bold caption), like the "What" row (board C3g "Going"). A choice without a picture shows "–".
public struct ChoiceCircles: View {
    public struct Choice: Equatable, Sendable, Identifiable {
        public var id: String
        public var picture: KitSlot?
        public var caption: String
        public var isPicked: Bool

        public init(id: String, picture: KitSlot?, caption: String, isPicked: Bool) {
            self.id = id
            self.picture = picture
            self.caption = caption
            self.isPicked = isPicked
        }
    }

    private let choices: [Choice]
    private let onPick: (String) -> Void

    public init(_ choices: [Choice], onPick: @escaping (String) -> Void) {
        self.choices = choices
        self.onPick = onPick
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Spacing.m) {
            ForEach(choices) { choice in
                Button { onPick(choice.id) } label: {
                    VStack(spacing: Spacing.xxs) {
                        ZStack {
                            if let picture = choice.picture {
                                KitIcon(picture, size: 64)
                            } else {
                                Text(verbatim: "–").crayonType(.title).foregroundStyle(CrayonColor.softText)
                            }
                        }
                        .frame(width: 88, height: 88)
                        .crayonBackground(.circle, fill: CrayonStyle.paper, seed: CrayonStyle.Seed.iconPicker)
                        .overlay {
                            if choice.isPicked {
                                Circle().stroke(CrayonColor.pickBlue, lineWidth: 5).frame(width: 96, height: 96)
                            }
                        }
                        Text(choice.caption).crayonType(.caption, bold: choice.isPicked).foregroundStyle(CrayonColor.ink)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(choice.caption)
                .accessibilityAddTraits(choice.isPicked ? [.isButton, .isSelected] : .isButton)
            }
        }
    }
}
