import CrayonKit
import KitArt
import SwiftUI

/// A bubble over a bus on the live strip (spec "A2 live look"): the kid's bus gets the number
/// plate, "{n} min" and the kid's face with "my bus"; an earlier bus the kid cannot catch gets a
/// small cream plate, its minutes and "too soon".
public struct LiveBusBubble: View {
    public enum Kind: Equatable, Sendable {
        case mine(face: KidFace.Badge, name: String, myBus: String)
        case tooSoon(String)
    }

    private let service: String
    private let minutes: String
    private let kind: Kind

    public init(service: String, minutes: String, kind: Kind) {
        self.service = service
        self.minutes = minutes
        self.kind = kind
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                NumberPlate(service, isMine: isMine)
                Text(minutes).crayonType(isMine ? .head : .body, bold: true).foregroundStyle(CrayonColor.ink)
                    .lineLimit(1).fixedSize()
            }
            switch kind {
            case let .mine(face, name, myBus):
                HStack(spacing: Spacing.xs) {
                    KidFace(face, name: name, size: 32)
                    Text(myBus).crayonType(.caption, bold: true).foregroundStyle(CrayonColor.ink).fixedSize()
                }
            case let .tooSoon(text):
                Text(text).crayonType(.caption).foregroundStyle(CrayonColor.softText).fixedSize()
            }
        }
        .padding(.horizontal, Spacing.s)
        .padding(.top, Spacing.xs)
        .padding(.bottom, Spacing.xs + 16)
        .background {
            CrayonSurface(.speechBubble(tailX: 0.5, tailHeight: 16), fill: CrayonStyle.paper,
                          seed: CrayonStyle.Seed.bubble + (isMine ? 1 : 2))
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
    }

    private var isMine: Bool { if case .mine = kind { true } else { false } }
}

/// A bus number plate: white for the kid's bus (76 × 40, 30 bold), cream for the others.
public struct NumberPlate: View {
    private let number: String
    private let isMine: Bool

    public init(_ number: String, isMine: Bool) {
        self.number = number
        self.isMine = isMine
    }

    public var body: some View {
        Text(number)
            .font(Font(FontRegistrar.font(size: isMine ? 30 : 24, weight: .bold)))
            .foregroundStyle(CrayonColor.ink)
            .lineLimit(1).fixedSize()
            .frame(minWidth: isMine ? 76 : 64, minHeight: isMine ? 40 : 36)
            .background {
                CrayonSurface(.roundedRect(cornerRadius: 8),
                              fill: CrayonFill.paper(isMine ? CrayonColor.card : CrayonColor.plateCream),
                              marker: .thin, seed: CrayonStyle.Seed.bubble + 7)
            }
    }
}
