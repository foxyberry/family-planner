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
        /// How many colour swatches the card shows (kid colours 0 to `colourCount` − 1).
        public var colourCount: Int
        /// The face pictures, in order.
        public var faces: [KitSlot]

        public init(name: String, namePlaceholder: String, age: String, agePlaceholder: String, colour: String,
                    face: String, colourCount: Int, faces: [KitSlot]) {
            self.name = name
            self.namePlaceholder = namePlaceholder
            self.age = age
            self.agePlaceholder = agePlaceholder
            self.colour = colour
            self.face = face
            self.colourCount = colourCount
            self.faces = faces
        }
    }

    /// The card's lines: the second column fits the two faces; the first column keeps room for the
    /// four swatches.
    public static func lines(_ layout: GrownupLayout, words: Words) -> FormLines {
        let sizing = layout.sizing, swatches = CGFloat(words.colourCount)
        return layout.formLines(secondLabels: [words.age, words.face],
                                secondControlWidth: CGFloat(words.faces.count) * sizing.pickedFace
                                    + CGFloat(max(words.faces.count - 1, 0)) * sizing(Spacing.sm),
                                firstControlMinimum: swatches * ColourSwatch.frame(sizing)
                                    + max(swatches - 1, 0) * sizing(Spacing.sm))
    }

    @Environment(\.sizing) private var sizing
    private let words: Words
    @Binding private var name: String
    @Binding private var age: String
    private let badge: KidFace.Badge
    private let colorIndex: Int
    private let face: String
    private let onColour: (Int) -> Void
    private let onFace: (String) -> Void

    /// `badge`: the face inside the Name field. `face`: the picked picture's slot name.
    public init(words: Words, name: Binding<String>, age: Binding<String>, badge: KidFace.Badge,
                colorIndex: Int, face: String, onColour: @escaping (Int) -> Void, onFace: @escaping (String) -> Void) {
        self.words = words
        _name = name
        _age = age
        self.badge = badge
        self.colorIndex = colorIndex
        self.face = face
        self.onColour = onColour
        self.onFace = onFace
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: sizing.formRowGap) {
            FormRow(words.name, kind: .field, second: words.age) {
                CrayonField(words.namePlaceholder, text: $name) {
                    KidFace(badge, size: sizing(KidFace.medium))
                }
            } secondControl: {
                CrayonField(words.agePlaceholder, text: $age)
                    .keyboardType(.numberPad)
            }
            FormRow(words.colour, kind: .choice, second: words.face) {
                HStack(spacing: sizing(Spacing.sm)) {
                    ForEach(0..<words.colourCount, id: \.self) { colour in
                        ColourSwatch(colorIndex: colour, isPicked: colorIndex == colour) { onColour(colour) }
                    }
                }
            } secondControl: {
                HStack(spacing: sizing(Spacing.sm)) {
                    ForEach(words.faces, id: \.self) { slot in
                        faceButton(slot)
                    }
                }
                .partInset()
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private func faceButton(_ slot: KitSlot) -> some View {
        let isPicked = face == slot.rawValue
        return Button { onFace(slot.rawValue) } label: {
            // Board S1: each face on a white disc with an ink circle; the pick adds the blue ring.
            // 64 × s; the picture keeps its 56 : 64.
            KitIcon(slot, size: sizing.pickedFace * 56 / 64)
                .frame(width: sizing.pickedFace, height: sizing.pickedFace)
                .background { CrayonSurface(.circle, fill: CrayonStyle.paper, marker: .thin, seed: CrayonStyle.Seed.kidCardFace) }
                .overlay {
                    if isPicked {
                        Circle().stroke(CrayonColor.pickBlue, lineWidth: sizing(5))
                            .frame(width: sizing.pickedFaceRing, height: sizing.pickedFaceRing)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
