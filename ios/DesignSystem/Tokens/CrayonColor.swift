import SwiftUI

/// Board 0a colours for views. Use these instead of hex values in components.
public enum CrayonColor {
    public static let kidABlue = CrayonPalette.kidABlue.color
    public static let kidBOrange = CrayonPalette.kidBOrange.color
    public static let onTimeGreen = CrayonPalette.onTimeGreen.color
    public static let handRed = CrayonPalette.handRed.color
    public static let paper = CrayonPalette.paper.color
    public static let marker = CrayonPalette.marker.color
    public static let softText = CrayonPalette.softText.color
    public static let hurry = CrayonPalette.hurry.color
    public static let nowSky = CrayonPalette.nowSky.color
    public static let goYellow = CrayonPalette.goYellow.color
    public static let kidApricot = CrayonPalette.kidApricot.color
    public static let card = CrayonPalette.card.color
    public static let doneGreen = CrayonPalette.doneGreen.color
    public static let ink = CrayonPalette.ink.color
    public static let onTimeText = CrayonPalette.onTimeText.color
    public static let lateText = CrayonPalette.lateText.color
    public static let link = CrayonPalette.link.color
    public static let night = CrayonPalette.night.color
    public static let nightText = CrayonPalette.nightText.color

    /// Colours a parent can pick for a child (blue, orange, green, purple).
    public static let kidPalette: [Color] = [
        CrayonPalette.kidABlue.color, CrayonPalette.kidBOrange.color,
        CrayonPalette.onTimeGreen.color, CrayonPalette.kidPurple.color,
    ]
}
