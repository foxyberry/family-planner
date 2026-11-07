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
    public static let kidABlue = RGB(hex: 0x2E8FE0)
    public static let kidBOrange = RGB(hex: 0xF28C28)
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
}
