import SwiftUI

/// Board A1n: at night, kit pictures off the clock sit on a paper plate (a light circle with a
/// 3.5 pt chalk ring), because their black outlines need a light ground. The plate is the part's
/// box (its ring's outer edge on the frame) and the picture shrinks to 64 of 104 inside it.
/// By day the picture fills the box as it is.
public struct KitPlate<Picture: View>: View {
    private let look: KidLook
    private let size: CGFloat
    private let picture: Picture
    private let nightPicture: CGFloat

    /// `nightPicture`: the picture's share of the plate at night (A1n: 64 of 104; the 80 row: 56 of 80).
    public init(look: KidLook, size: CGFloat, nightPicture: CGFloat = 64.0 / 104.0,
                @ViewBuilder picture: () -> Picture) {
        self.look = look
        self.size = size
        self.nightPicture = nightPicture
        self.picture = picture()
    }

    public var body: some View {
        picture
            .frame(width: size, height: size)
            .scaleEffect(look == .night ? nightPicture : 1)
            .background {
                if look == .night {
                    Circle().fill(CrayonColor.plate)
                        .overlay(Circle().strokeBorder(CrayonColor.nightText, lineWidth: 3.5))
                }
            }
            .frame(width: size, height: size)
    }
}
