import CrayonKit
import KitArt
import SwiftUI

/// The kid card (board S1, layout v56 two columns; user 2026-11-21), shared by S1 and G6f "Add a
/// child": two rows on the form lines, 24 apart drawn. Row 1: Name (with the kid's face inside) and
/// Age; row 2: Colour swatches and Face pictures. Age and Face form a second column ending on the
/// right edge (drawn 802), under the first when the card is too narrow. Put it in a `PaperCard` with
/// `.formLines(KidCard.lines(layout, words:))`.
public struct KidCard: View {
    /// Every word the card shows, from the caller's State.
    public struct Words: Equatable, Sendable {
        public var name: String
        public var namePlaceholder: String
        public var age: String
        public var agePlaceholder: String
        public var colour: String
        public var face: String
        /// One name per colour swatch, in order (VoiceOver).
        public var colourNames: [String]
        /// The face pictures and their names, in order.
        public var faces: [(slot: KitSlot, name: String)]

        public init(name: String, namePlaceholder: String, age: String, agePlaceholder: String, colour: String,
                    face: String, colourNames: [String], faces: [(slot: KitSlot, name: String)]) {
            self.name = name
            self.namePlaceholder = namePlaceholder
            self.age = age
            self.agePlaceholder = agePlaceholder
            self.colour = colour
            self.face = face
            self.colourNames = colourNames
            self.faces = faces
        }

        public static func == (lhs: Words, rhs: Words) -> Bool {
            lhs.name == rhs.name && lhs.namePlaceholder == rhs.namePlaceholder && lhs.age == rhs.age
                && lhs.agePlaceholder == rhs.agePlaceholder && lhs.colour == rhs.colour && lhs.face == rhs.face
                && lhs.colourNames == rhs.colourNames
                && lhs.faces.map(\.slot) == rhs.faces.map(\.slot) && lhs.faces.map(\.name) == rhs.faces.map(\.name)
        }
    }

    /// The card's lines: the second column fits the two faces; the first column keeps room for the
    /// four swatches.
    public static func lines(_ layout: GrownupLayout, words: Words) -> FormLines {
        let sizing = layout.sizing, swatches = CGFloat(words.colourNames.count)
        return layout.formLines(secondLabels: [words.age, words.face],
                                secondControlWidth: CGFloat(words.faces.count) * sizing.pickedFace
                                    + CGFloat(max(words.faces.count - 1, 0)) * Spacing.sm,
                                firstControlMinimum: swatches * ColourSwatch.frame(sizing)
                                    + max(swatches - 1, 0) * Spacing.sm)
    }

    @Environment(\.sizing) private var sizing
    private let words: Words
    @Binding private var name: String
    @Binding private var age: String
    private let badge: KidFace.Badge
    private let shownName: String
    private let colorIndex: Int
    private let face: String
    private let onColour: (Int) -> Void
    private let onFace: (String) -> Void

    /// `badge` and `shownName`: the face inside the Name field. `face`: the picked picture's slot name.
    public init(words: Words, name: Binding<String>, age: Binding<String>, badge: KidFace.Badge, shownName: String,
                colorIndex: Int, face: String, onColour: @escaping (Int) -> Void, onFace: @escaping (String) -> Void) {
        self.words = words
        _name = name
        _age = age
        self.badge = badge
        self.shownName = shownName
        self.colorIndex = colorIndex
        self.face = face
        self.onColour = onColour
        self.onFace = onFace
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: sizing.formRowGap) {
            FormRow(words.name, kind: .field, second: words.age) {
                CrayonField(words.namePlaceholder, text: $name) {
                    KidFace(badge, name: shownName, size: KidFace.medium)
                }
            } secondControl: {
                CrayonField(words.agePlaceholder, text: $age)
                    .keyboardType(.numberPad)
            }
            FormRow(words.colour, kind: .choice, second: words.face) {
                HStack(spacing: Spacing.sm) {
                    ForEach(Array(words.colourNames.enumerated()), id: \.offset) { colour, colourName in
                        ColourSwatch(colorIndex: colour, isPicked: colorIndex == colour,
                                     accessibilityLabel: colourName) { onColour(colour) }
                    }
                }
            } secondControl: {
                HStack(spacing: Spacing.sm) {
                    ForEach(words.faces, id: \.slot) { choice in
                        faceButton(choice.slot, name: choice.name)
                    }
                }
                .partInset()
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func faceButton(_ slot: KitSlot, name: String) -> some View {
        let isPicked = face == slot.rawValue
        return Button { onFace(slot.rawValue) } label: {
            // Board S1: each face on a white disc with an ink circle; the pick adds the blue ring.
            // Spec "Part floors": 64 × s, never under 56; the picture keeps its 56 : 64.
            KitIcon(slot, size: sizing.pickedFace * 56 / 64)
                .frame(width: sizing.pickedFace, height: sizing.pickedFace)
                .background { CrayonSurface(.circle, fill: CrayonStyle.paper, marker: .thin, seed: CrayonStyle.Seed.kidCardFace) }
                .overlay {
                    if isPicked {
                        Circle().stroke(CrayonColor.pickBlue, lineWidth: 5)
                            .frame(width: sizing.pickedFaceRing, height: sizing.pickedFaceRing)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isPicked ? [.isButton, .isSelected] : .isButton)
    }
}
