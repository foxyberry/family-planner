import CrayonKit
import KitArt
import SwiftUI

// Home's right panel parts (spec A1 "Next things" and "Kid chips", layout v75, 2026-11-22): the time
// cell with its time-left dots, one family row (or the larger next card) and the kid chips. Every
// size is a board value × s; the words come from the caller's State.

/// What a row's time cell says (spec A1 "The time cell"): when the kid must act.
public enum TimeCellContent: Equatable, Sendable {
    /// Within the hour: "{n}" and its unit over the time-left dots, `dots` red of six (one per 10 min).
    case soon(number: String, unit: String, dots: Int)
    /// Later today: the clock time and its period ("4:15", "pm"); the card draws the time 36, the period 24.
    case at(time: String, period: String)
    /// Another day: the day ("Tomorrow", "Tue", "Tue 1 Dec") over the time.
    case day(label: String, time: String)
}

/// Six time-left dots (spec A1 "Time-left dots"): 11 each, gap 5; red (`handRed`) for the time left,
/// the rest paper with a soft 2 ring at 40 % (night: `nightControl`). They go out from the right. A dot
/// pops in or out; with `breathes` (the next card only) the last red dot breathes, 100 → 60 % over 2 s.
/// Reduce Motion: no pop, no breathing.
public struct TimeDots: View {
    public static let count = 6
    public static let side: CGFloat = 11
    public static let gap: CGFloat = 5
    /// The row's board width: 6 × 11 + 5 × 5.
    public static let width = CGFloat(count) * side + CGFloat(count - 1) * gap

    private let red: Int
    private let breathes: Bool
    private let look: KidLook
    @Environment(\.sizing) private var sizing
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    public init(red: Int, breathes: Bool, look: KidLook) {
        self.red = min(max(red, 0), Self.count)
        self.breathes = breathes
        self.look = look
    }

    public var body: some View {
        HStack(spacing: sizing(Self.gap)) {
            ForEach(0..<Self.count, id: \.self) { index in
                dot(isRed: index < red, isLast: index == red - 1)
            }
        }
        .animation(reduceMotion ? nil : .spring(duration: 0.3, bounce: 0.5), value: red)
        .onAppear {
            guard breathes, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { dim = true }
        }
    }

    private func dot(isRed: Bool, isLast: Bool) -> some View {
        let side = sizing(Self.side)
        return ZStack {
            Circle().fill(look == .day ? CrayonColor.paper : CrayonColor.nightControl)
                .overlay(Circle().strokeBorder(CrayonColor.softText.opacity(look == .day ? 0.4 : 0), lineWidth: sizing(2)))
            Circle().fill(CrayonColor.handRed)
                .scaleEffect(isRed ? 1 : 0.01)
                .opacity(isRed ? (isLast && breathes && dim && !reduceMotion ? 0.6 : 1) : 0)
        }
        .frame(width: side, height: side)
    }
}

/// A row's time cell (spec A1 "The time cell"), right-aligned on its right edge (1040): within the hour
/// "{n} min" over the dots; later the clock time; another day the day over the time. `card` draws the
/// next card's size (time 36).
public struct TimeCell: View {
    private let content: TimeCellContent
    private let card: Bool
    private let breathes: Bool
    private let look: KidLook
    @Environment(\.sizing) private var sizing

    public init(_ content: TimeCellContent, card: Bool, breathes: Bool, look: KidLook) {
        self.content = content
        self.card = card
        self.breathes = breathes
        self.look = look
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: sizing(4)) {
            switch content {
            case let .soon(number, unit, dots):
                HStack(alignment: .firstTextBaseline, spacing: sizing(4)) {
                    Text(number).crayonType(card ? .head : .body, bold: true).foregroundStyle(look.ink)
                    Text(unit).crayonType(.caption, bold: true).foregroundStyle(look.ink)
                }
                .monospacedDigit()
                TimeDots(red: dots, breathes: breathes, look: look)
            case let .at(time, period):
                HStack(alignment: .firstTextBaseline, spacing: sizing(card ? 4 : 6)) {
                    Text(time).crayonType(card ? .head : .caption, bold: true)
                    Text(period).crayonType(.caption, bold: true)
                }
                .foregroundStyle(card ? look.ink : look.softText)
            case let .day(label, time):
                Text(label).crayonType(.caption, bold: true).foregroundStyle(look.softText)
                Text(time).crayonType(card ? .head : .caption, bold: true)
                    .foregroundStyle(card ? look.ink : look.softText)
            }
        }
        .lineLimit(1)
        // A day label wider than the cell ("Tomorrow") reaches left into the panel's margin, never cut.
        .fixedSize()
    }
}

/// One family row in home's next list, or the next card (spec A1 "The row", "Mission rows", "The
/// next card"): the time cell (right edge 112 from the panel's left), the picture (56 at 124; card 72),
/// then the title at 12 past the picture with the kids' faces under it (32 overlapping by 8; card 36).
/// A later row's title is `laterText` and its picture 75 %; a `hatch` makes it a mission row: the kid's
/// colour (or `sand` for a shared outing) as a crayon hatch from 12 left of the panel to its right
/// edge, the title in ink and a crayon "›" 10 in from the right. `faded`: a tapped-away kid's row
/// (30 %, 10 s).
public struct NextThingRow: View {
    public enum Size: Equatable, Sendable { case row, card }
    public enum Hatch: Equatable, Sendable {
        /// The kid's colour, from `Kid.colorIndex`.
        case kid(Int)
        /// An outing for two or more kids: the one warm neutral (`sand`).
        case shared
    }

    /// Board units, from the panel's left (928) and its width (408).
    public static let width: CGFloat = 408
    public static let timeRight: CGFloat = 112
    public static let pictureLeft: CGFloat = 124
    public static let titleGap: CGFloat = 12
    /// The hatch bleeds 12 left of the panel; inside it the chevron ends 10 from the right.
    public static let hatchBleed: CGFloat = 12
    public static let chevronInset: CGFloat = 10
    public static let chevronSide: CGFloat = 32
    public static let chevronLine: CGFloat = 6.5
    /// Heights (layout v75): a later row 69, a mission row 81, the next card 112.
    public static func height(size: Size, isMission: Bool) -> CGFloat {
        switch size {
        case .row: isMission ? 81 : 69
        case .card: 112
        }
    }

    private let time: TimeCellContent
    private let picture: KitSlot
    private let title: String
    private let faces: [KidFace.Badge]
    private let hatch: Hatch?
    private let size: Size
    private let faded: Bool
    private let look: KidLook
    @Environment(\.sizing) private var sizing

    public init(time: TimeCellContent, picture: KitSlot, title: String, faces: [KidFace.Badge], hatch: Hatch?,
                size: Size, faded: Bool, look: KidLook) {
        self.time = time
        self.picture = picture
        self.title = title
        self.faces = faces
        self.hatch = hatch
        self.size = size
        self.faded = faded
        self.look = look
    }

    private var pictureSide: CGFloat { size == .card ? 72 : 56 }
    private var faceSide: CGFloat { size == .card ? 36 : 32 }
    private var titleLeft: CGFloat { Self.pictureLeft + pictureSide + Self.titleGap }
    private var titleRight: CGFloat {
        hatch == nil ? Self.width : Self.width - Self.chevronInset - Self.chevronSide - 8
    }

    public var body: some View {
        let height = sizing(Self.height(size: size, isMission: hatch != nil))
        // On a hatch the words stay dark, by night too: the kid colours are light.
        let words = hatch == nil ? look : .day
        ZStack(alignment: .leading) {
            TimeCell(time, card: size == .card, breathes: size == .card, look: words)
                .frame(width: sizing(Self.timeRight), alignment: .trailing)
            KitPlate(look: look, size: sizing(pictureSide), nightPicture: 40.0 / 56.0) {
                KitIcon(picture, size: sizing(pictureSide))
            }
            .opacity(size == .row && hatch == nil ? 0.75 : 1)
            .offset(x: sizing(Self.pictureLeft))
            VStack(alignment: .leading, spacing: sizing(-2)) {
                Text(title).crayonType(size == .card ? .head : .body, bold: true)
                    .foregroundStyle(hatch == nil && size == .row ? words.laterText : words.ink)
                    .lineLimit(1).truncationMode(.tail)
                HStack(spacing: sizing(-8)) {
                    ForEach(Array(faces.enumerated()), id: \.offset) { _, face in
                        KidFace(face, size: sizing(faceSide))
                    }
                }
            }
            .frame(width: sizing(titleRight - titleLeft), alignment: .leading)
            .offset(x: sizing(titleLeft))
            if hatch != nil {
                MarkerIcon(.chevronRight, size: sizing(Self.chevronSide), color: words.ink, line: Self.chevronLine)
                    .offset(x: sizing(Self.width - Self.chevronInset - Self.chevronSide))
            }
        }
        .frame(width: sizing(Self.width), height: height, alignment: .leading)
        .background(alignment: .trailing) {
            if let hatch {
                CrayonSurface(.roundedRect(cornerRadius: 20), fill: fill(hatch), marker: MarkerStyle.thin,
                              markerColor: .clear, seed: CrayonStyle.Seed.nextThing + seedIndex(hatch))
                    .frame(width: sizing(Self.width + Self.hatchBleed), height: height)
            }
        }
        .opacity(faded ? 0.3 : 1)
    }

    private func fill(_ hatch: Hatch) -> CrayonFill {
        switch hatch {
        case let .kid(index): CrayonStyle.kid(index)
        case .shared: CrayonFill(color: CrayonPalette.sand.color, hachure: HachureStyle(degrees: -40))
        }
    }

    private func seedIndex(_ hatch: Hatch) -> UInt32 {
        switch hatch {
        case let .kid(index): UInt32(max(0, index))
        case .shared: 50
        }
    }
}

/// One kid chip at the bottom of home (spec A1 "Kid chips"): 96 tall, radius 48, the kid's face 56 and
/// the picture of what the kid is doing now 60; with one kid the chip also shows the name. The picked
/// chip is the kid's colour at 40 % with a 4 ink outline (night: chalk); the others `chip`.
/// Chip sizes by the number of kids (design answer, 2026-11-23): one or two kids face 56 and picture
/// 60, 10 apart; three kids face 46 and picture 46, 8 apart (100 wide, 8 inside the drawn 116); four
/// kids the face 56 alone, centred (choosing who comes first; the clock and list say what is on now).
public struct KidChip: View {
    public enum Fit: Equatable, Sendable {
        case regular, compact, faceOnly
    }

    public static let height: CGFloat = 96
    public static let face: CGFloat = 56
    public static let picture: CGFloat = 60
    public static let gap: CGFloat = 10
    public static let compactSide: CGFloat = 46
    public static let compactGap: CGFloat = 8

    private let face: KidFace.Badge
    private let picture: KitSlot
    private let name: String?
    private let isPicked: Bool
    private let fit: Fit
    private let look: KidLook
    private let action: () -> Void
    @Environment(\.sizing) private var sizing

    /// `name`: only with one kid (board E1). `fit`: from the number of kids.
    public init(face: KidFace.Badge, picture: KitSlot, name: String?, isPicked: Bool, fit: Fit, look: KidLook,
                action: @escaping () -> Void) {
        self.face = face
        self.picture = picture
        self.name = name
        self.isPicked = isPicked
        self.fit = fit
        self.look = look
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            let compact = fit == .compact
            let side = compact ? Self.compactSide : Self.face
            HStack(spacing: sizing(name != nil ? Spacing.s : compact ? Self.compactGap : Self.gap)) {
                KidFace(face, size: sizing(side))
                if let name {
                    Text(name).crayonType(.body, bold: true).foregroundStyle(look.ink).lineLimit(1)
                }
                if fit != .faceOnly {
                    KitPlate(look: look, size: sizing(compact ? Self.compactSide : Self.picture), nightPicture: 44.0 / 60.0) {
                        KitIcon(picture, size: sizing(compact ? Self.compactSide : Self.picture))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Spec "Crayon part inset": drawn one art inset inside the frame, and taps only on the drawn
            // capsule (touch rule 1).
            .partBackground(.capsule, fill: .paper(isPicked ? look.kid(face.colorIndex).opacity(0.4) : look.chip),
                            seed: CrayonStyle.Seed.kidChip + UInt32(max(0, face.colorIndex)),
                            marker: MarkerStyle(width: 4, roughness: 0.8, bowing: 0.8),
                            markerColor: isPicked ? look.outline : .clear, tap: .drawn)
        }
        .buttonStyle(.plain)
        .frame(height: sizing(Self.height))
    }
}
