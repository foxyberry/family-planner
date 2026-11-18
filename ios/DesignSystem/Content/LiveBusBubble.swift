import CrayonKit
import KitArt
import SwiftUI

/// The bubble over the kid's bus on the live strip (spec "A2 live look"): the number plate,
/// "{n} min" and the kid's face with "my bus". Every other bus gets a `LiveBusTag`.
public struct LiveBusBubble: View {
    /// About its drawn size (board A2: 220 × 132), which the tags keep clear of.
    public static let size = CGSize(width: 220, height: 132)
    private let service: String
    private let minutes: String
    private let face: KidFace.Badge
    private let name: String
    private let myBus: String

    public init(service: String, minutes: String, face: KidFace.Badge, name: String, myBus: String) {
        self.service = service
        self.minutes = minutes
        self.face = face
        self.name = name
        self.myBus = myBus
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                NumberPlate(service, isMine: true)
                Text(minutes).crayonType(.head, bold: true).foregroundStyle(CrayonColor.pictureInk)
                    .lineLimit(1).fixedSize()
            }
            HStack(spacing: Spacing.xs) {
                KidFace(face, name: name, size: 32)
                Text(myBus).crayonType(.caption, bold: true).foregroundStyle(CrayonColor.pictureInk).fixedSize()
            }
        }
        .padding(.horizontal, Spacing.s)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.xs + 16)
        .background {
            CrayonSurface(.speechBubble(tailX: 0.5, tailHeight: 16), fill: CrayonStyle.pictureGround,
                          markerColor: CrayonColor.pictureOutline, seed: CrayonStyle.Seed.bubble + 1)
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}

/// The tag over every bus but the kid's on the live strip (spec "A2 strip"): a small cream plate
/// (52 × 28, 24 bold; a bus that changes reads "34 → 33", the arrow drawn) and "{n} min" (or "too
/// soon"), caption bold, on paper, about 130 × 44. Tags that collide merge into one listing.
public struct LiveBusTag: View {
    public static let height: CGFloat = 44
    static let padding = Spacing.xs
    static let plateMinWidth: CGFloat = 52
    static let arrow: CGFloat = 20

    public enum Content: Equatable, Sendable {
        case bus(number: String, then: String?, minutes: String)
        /// Two or more tags merged: "34 · 12 min, 56 · 13 min".
        case listing(String)
    }

    private let content: Content

    public init(_ content: Content) {
        self.content = content
    }

    /// The tag's width on screen, measured in Playpen Sans (the plate and the words are 24 bold).
    public static func width(_ content: Content) -> CGFloat {
        switch content {
        case let .bus(number, then, minutes):
            2 * padding + plateWidth(number, then: then) + Spacing.xs + CrayonType.captionBoldWidth(minutes)
        case let .listing(text):
            2 * padding + CrayonType.captionBoldWidth(text)
        }
    }

    static func plateWidth(_ number: String, then: String?) -> CGFloat {
        var words = CrayonType.captionBoldWidth(number)
        if let then { words += Spacing.xxs + arrow + Spacing.xxs + CrayonType.captionBoldWidth(then) }
        return max(plateMinWidth, words + 2 * Spacing.xs)
    }

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            switch content {
            case let .bus(number, then, minutes):
                Plate(number: number, then: then)
                Text(minutes).crayonType(.caption, bold: true).foregroundStyle(CrayonColor.pictureInk)
                    .lineLimit(1).fixedSize()
            case let .listing(text):
                Text(text).crayonType(.caption, bold: true).foregroundStyle(CrayonColor.pictureInk)
                    .lineLimit(1).fixedSize()
            }
        }
        .padding(.horizontal, Self.padding)
        .frame(width: Self.width(content), height: Self.height)
        .background {
            CrayonSurface(.roundedRect(cornerRadius: 14), fill: CrayonStyle.paper, marker: .thin,
                          markerColor: CrayonColor.pictureOutline, seed: CrayonStyle.Seed.bubble + 9)
        }
        .accessibilityElement(children: .combine)
    }
}

extension LiveBusTag {
    /// The tag's cream plate (52 × 28, 24 bold), also the legend's faded plates.
    public struct Plate: View {
        let number: String
        let then: String?

        public init(number: String, then: String?) {
            self.number = number
            self.then = then
        }

        public var body: some View {
            HStack(spacing: Spacing.xxs) {
                Text(number)
                if let then {
                    MarkerIcon(.arrowRight, size: LiveBusTag.arrow, color: CrayonColor.pictureInk)
                    Text(then)
                }
            }
            .font(Font(FontRegistrar.font(size: 24, weight: .bold)))
            .foregroundStyle(CrayonColor.pictureInk)
            .lineLimit(1).fixedSize()
            .frame(width: LiveBusTag.plateWidth(number, then: then), height: 28)
            .background {
                CrayonSurface(.roundedRect(cornerRadius: 8), fill: CrayonFill.paper(CrayonColor.plateCream),
                              marker: .thin, markerColor: CrayonColor.pictureOutline, seed: CrayonStyle.Seed.bubble + 8)
            }
        }
    }
}

/// A bus number plate: white for the kid's bus (76 × 40, 30 bold), cream for the others; `small`
/// (the way strip's legend, board A2): white 56 × 30 with 24 bold.
public struct NumberPlate: View {
    private let number: String
    private let isMine: Bool
    private let small: Bool

    public init(_ number: String, isMine: Bool, small: Bool = false) {
        self.number = number
        self.isMine = isMine
        self.small = small
    }

    public var body: some View {
        let big = isMine && !small
        Text(number)
            .font(Font(FontRegistrar.font(size: big ? 30 : 24, weight: .bold)))
            .foregroundStyle(CrayonColor.pictureInk)
            .lineLimit(1).fixedSize()
            .frame(minWidth: small ? 56 : big ? 76 : 64, minHeight: small ? 30 : big ? 40 : 36)
            .background {
                CrayonSurface(.roundedRect(cornerRadius: 8),
                              fill: CrayonFill.paper(isMine ? CrayonColor.pictureGround : CrayonColor.plateCream),
                              marker: .thin, markerColor: CrayonColor.pictureOutline, seed: CrayonStyle.Seed.bubble + 7)
            }
    }
}
