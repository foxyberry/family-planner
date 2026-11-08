import SwiftUI

/// An sRGB colour with 0...1 components. The single source for every palette value,
/// so the SwiftUI colour and the contrast check can never disagree.
public struct RGB: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
    }

    public var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: 1) }
}

/// Board 0a palette as raw values.
public enum CrayonPalette {
    // Fills
    /// One colour per kid, day and night (board 00): the KidFace ring and the KidBand edge.
    public static let kidA = RGB(hex: 0x56B4E9)
    public static let kidB = RGB(hex: 0xE69F00)
    /// Board 0c2: the light tints of the chosen kid's band, its edge line, and the progress ring's track.
    public static let kidATint = RGB(hex: 0xBFE3F7)
    public static let kidATintEdge = RGB(hex: 0x8CCBEE)
    public static let kidBTint = RGB(hex: 0xFCD9A6)
    public static let kidBTintEdge = RGB(hex: 0xF2B35E)
    public static let ringTrack = RGB(hex: 0xE2D9C6)
    /// ✓ done, picked and focus, for any kid; not a kid colour (was kidABlue).
    public static let pickBlue = RGB(hex: 0x2E8FE0)
    public static let onTimeGreen = RGB(hex: 0x3FAE5A)
    public static let handRed = RGB(hex: 0xE5484D)
    public static let paper = RGB(hex: 0xF6F2EA)
    public static let marker = RGB(hex: 0x1E1B22)
    public static let softText = RGB(hex: 0x625D6E)
    public static let hurry = RGB(hex: 0xFFB341)
    public static let nowSky = RGB(hex: 0x8FD3F4)
    public static let goYellow = RGB(hex: 0xFFD23F)
    public static let kidApricot = RGB(hex: 0xFBC97A)
    public static let card = RGB(hex: 0xFFFFFF)
    public static let doneGreen = RGB(hex: 0x9ED39A)
    public static let kidPurple = RGB(hex: 0x9B6BD6)
    // Clock slot colours (board A1). Text never sits on these, so contrast rules do not apply.
    public static let mint = RGB(hex: 0x7FD6B5)
    public static let orange = RGB(hex: 0xF7A84B)
    public static let green = RGB(hex: 0xA8DB7A)
    // Way strip scenery (board A2-MVP): the ground and the road and tree crowns.
    public static let meadow = RGB(hex: 0xD6ECC3)
    public static let leaf = RGB(hex: 0x3FAE5A)
    /// Number plates of buses that are not the kid's (spec CrayonKit parts, `NumberPlate`).
    public static let plateCream = RGB(hex: 0xFFF0BF)
    public static let coral = RGB(hex: 0xF9A88A)
    public static let lilac = RGB(hex: 0xB9A3F0)
    public static let pink = RGB(hex: 0xF7A8CF)
    // Text (darker shades that pass contrast on paper)
    public static let ink = RGB(hex: 0x2B2833)
    public static let onTimeText = RGB(hex: 0x17744D)
    public static let lateText = RGB(hex: 0xC62F35)
    public static let link = RGB(hex: 0x2F6FD0)
    // Night
    public static let night = RGB(hex: 0x22213A)
    public static let nightText = RGB(hex: 0xF4EFFF)
    /// Board A1n: soft text, the lit clock face and the plate under pictures at night.
    public static let nightSoftText = RGB(hex: 0xC9C3E0)
    public static let litPaper = RGB(hex: 0xEFE8D8)
    public static let plate = RGB(hex: 0xFBF8F1)
}
