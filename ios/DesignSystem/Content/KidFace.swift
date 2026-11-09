import CrayonKit
import KitArt
import SwiftUI

/// A kid's face in their colour ring, next to their name everywhere (spec "KidFace"). The ring is a
/// crayon UI shape drawn in code (stroke about 9 % of the box, a fixed seed per kid, the kid's one
/// colour by day and night); only the face is a kit picture, centred at 86 % of the box (the
/// face drawing fills only 68 % of its own box). A kid with no face yet (`face` empty, S1) shows
/// their colour dot. One accessibility element labelled with the name.
public struct KidFace: View {
    /// What a tab or row needs to show a kid's face.
    public struct Badge: Equatable, Sendable {
        public var face: String
        public var colorIndex: Int

        public init(face: String, colorIndex: Int) {
            self.face = face
            self.colorIndex = colorIndex
        }
    }

    /// The text's line height rounded up to the 8 pt grid: 48 beside head 36, 40 beside body 30,
    /// 32 beside caption 24. Gap to the name: 16 beside 48, 8 beside 40 and 32.
    public static let large: CGFloat = 48
    public static let medium: CGFloat = 40
    public static let small: CGFloat = 32

    public static func gap(for size: CGFloat) -> CGFloat { size >= large ? Spacing.s : Spacing.xs }

    private let badge: Badge
    private let size: CGFloat
    private let name: String
    private let showsRing: Bool

    /// `showsRing: false` inside a progress ring (the morning kid list), where the kid's colour
    /// appears only as missions get done (user, 2026-11-09).
    public init(_ badge: Badge, name: String, size: CGFloat = KidFace.large, showsRing: Bool = true) {
        self.badge = badge
        self.size = size
        self.name = name
        self.showsRing = showsRing
    }

    public var body: some View {
        ZStack {
            if showsRing {
                CrayonSurface(.circle, fill: nil,
                              marker: MarkerStyle(width: size * 0.09, roughness: 0.6, bowing: 0.6),
                              markerColor: CrayonColor.kid(badge.colorIndex),
                              seed: CrayonStyle.Seed.kidFace + UInt32(max(0, badge.colorIndex)))
            }
            if badge.face.isEmpty {
                // No face picked yet (S1): the kid's colour dot inside the ring.
                CrayonSurface(.circle, fill: CrayonStyle.kid(badge.colorIndex), marker: .thin,
                              markerColor: CrayonColor.kid(badge.colorIndex), seed: CrayonStyle.Seed.kidFace + 10)
                    .frame(width: size * 0.5, height: size * 0.5)
            } else {
                KitIcon(KitSlot(iconName: badge.face), size: size * 0.86)
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
    }
}
