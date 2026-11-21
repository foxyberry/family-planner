import CrayonKit
import KitArt
import SwiftUI

/// The kid card (board S1, layout v59), shared by S1 and G6f "Add a child": four rows stacked on the
/// form lines (label 78, control 192, right edge 808), 24 apart drawn. Name stretches to the right
/// edge with the kid's face inside; Age is a fixed 152 field; Colour holds the swatches and Face the
/// kid pictures, both starting on the drawn line 198. Put it in a `PaperCard` with `formLines`.
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

    /// Board S1: the Age field, 152 wide (drawn 140).
    public static let ageWidth: CGFloat = 152

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
            FormRow(words.name, kind: .field) {
                CrayonField(words.namePlaceholder, text: $name) {
                    KidFace(badge, name: shownName, size: KidFace.medium)
                }
            }
            FormRow(words.age, kind: .field) {
                CrayonField(words.agePlaceholder, text: $age)
                    .keyboardType(.numberPad)
                    .frame(width: Self.ageWidth)
            }
            FormRow(words.colour, kind: .choice) {
                HStack(spacing: Spacing.sm) {
                    ForEach(Array(words.colourNames.enumerated()), id: \.offset) { colour, colourName in
                        ColourSwatch(colorIndex: colour, isPicked: colorIndex == colour,
                                     accessibilityLabel: colourName) { onColour(colour) }
                    }
                }
            }
            FormRow(words.face, kind: .choice) {
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
