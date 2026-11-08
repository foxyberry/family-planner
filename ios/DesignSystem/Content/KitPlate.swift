import SwiftUI

/// Board A1n: at night, kit pictures off the clock sit on a paper plate (a light circle with a
/// 3.5 pt chalk ring), because their black outlines need a light ground. By day they sit as they are.
public struct KitPlate<Picture: View>: View {
    private let look: KidLook
    private let size: CGFloat
    private let picture: Picture

    public init(look: KidLook, size: CGFloat, @ViewBuilder picture: () -> Picture) {
        self.look = look
        self.size = size
        self.picture = picture()
    }

    public var body: some View {
        picture
            .frame(width: size, height: size)
            .background {
                if look == .night {
                    Circle().fill(CrayonColor.plate)
                        .overlay(Circle().stroke(CrayonColor.nightText, lineWidth: 3.5))
                        .frame(width: size * 1.15, height: size * 1.15)
                }
            }
    }
}
