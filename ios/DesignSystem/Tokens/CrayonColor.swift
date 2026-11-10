import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Board 0a colours for views. Use these instead of hex values in components.
///
/// Spec "Night mapping": the page, text, chrome and outline tokens follow the colour scheme, so
/// grown-up screens follow the iPad's own dark mode with no work in the screens. Kid screens and
/// setup pin the light scheme and take their night look from `KidLook`. Picture grounds (circles
/// and plates under pictures, the clock hub, speech bubbles) and crayon on-states keep ink: use the
/// `picture…` tokens there.
public enum CrayonColor {
    public static let kidA = CrayonPalette.kidA.color
    public static let kidB = CrayonPalette.kidB.color
    public static let pickBlue = CrayonPalette.pickBlue.color
    public static let onTimeGreen = CrayonPalette.onTimeGreen.color
    public static let meadow = CrayonPalette.meadow.color
    public static let leaf = CrayonPalette.leaf.color
    public static let plateCream = CrayonPalette.plateCream.color
    public static let hillGreen = CrayonPalette.green.color
    public static let handRed = CrayonPalette.handRed.color
    /// The page: paper by day, the night page in dark mode.
    public static let paper = adaptive(CrayonPalette.paper, night: CrayonPalette.night)
    /// Marker fills and lines: marker by day, chalk in dark mode.
    public static let marker = adaptive(CrayonPalette.marker, night: CrayonPalette.chalk)
    public static let softText = adaptive(CrayonPalette.softText, night: CrayonPalette.nightSoftText)
    public static let hurry = CrayonPalette.hurry.color
    public static let nowSky = CrayonPalette.nowSky.color
    public static let goYellow = CrayonPalette.goYellow.color
    public static let kidApricot = CrayonPalette.kidApricot.color
    /// Chrome (cards, fields, off tabs and chips, round buttons): white by day, night control in
    /// dark mode.
    public static let card = adaptive(CrayonPalette.card, night: CrayonPalette.nightControl)
    public static let doneGreen = CrayonPalette.doneGreen.color
    public static let ink = adaptive(CrayonPalette.ink, night: CrayonPalette.nightText)
    public static let onTimeText = CrayonPalette.onTimeText.color
    public static let lateText = adaptive(CrayonPalette.lateText, night: CrayonPalette.nightLate)
    public static let link = adaptive(CrayonPalette.link, night: CrayonPalette.nightLink)
    public static let night = CrayonPalette.night.color
    public static let nightText = CrayonPalette.nightText.color
    public static let nightSoftText = CrayonPalette.nightSoftText.color
    public static let moonPaper = CrayonPalette.moonPaper.color
    public static let nightControl = CrayonPalette.nightControl.color
    public static let chalk = CrayonPalette.chalk.color
    public static let litPaper = CrayonPalette.litPaper.color

    /// A part's crayon outline: the drawn marker grey by day, chalk in dark mode.
    public static let outline = adaptive(white: 0.12, night: CrayonPalette.chalk)
    /// Picture grounds: white by day, moon paper in dark mode, always with ink on them.
    public static let pictureGround = adaptive(CrayonPalette.card, night: CrayonPalette.moonPaper)
    /// Text and outlines on picture grounds and on crayon on-states (a picked tab): ink in both.
    public static let pictureInk = CrayonPalette.ink.color
    public static let pictureSoftText = CrayonPalette.softText.color
    public static let pictureOutline = Color(white: 0.12)
    /// Marker lines and veils on lit and picture grounds: marker in both.
    public static let pictureMarker = CrayonPalette.marker.color
    /// A white tick on a picked check: white in both.
    public static let tick = CrayonPalette.card.color
    /// The edit clock's face under the slots: paper by day, lit paper in dark mode (a lit ground).
    public static let clockFace = adaptive(CrayonPalette.paper, night: CrayonPalette.litPaper)
    /// Lit grounds under drawn scenery (A2's way strip): the page by day, lit paper in dark mode.
    public static let litGround = adaptive(CrayonPalette.paper, night: CrayonPalette.litPaper)
    /// The layer behind a card: ink 35 % by day, black 45 % in dark mode.
    public static let dim = adaptiveDim()

    /// Colours a parent can pick for a child (blue, orange, green, purple).
    public static let kidPalette: [Color] = [
        CrayonPalette.kidA.color, CrayonPalette.kidB.color,
        CrayonPalette.onTimeGreen.color, CrayonPalette.kidPurple.color,
    ]

    /// A kid's colour from `Kid.colorIndex`; more kids than colours wrap around.
    public static func kid(_ colorIndex: Int) -> Color {
        let count = kidPalette.count
        return kidPalette[((colorIndex % count) + count) % count]
    }

    private static func adaptive(_ day: RGB, night: RGB) -> Color {
        #if canImport(UIKit)
        Color(UIColor { $0.userInterfaceStyle == .dark ? night.uiColor : day.uiColor })
        #else
        day.color
        #endif
    }

    private static func adaptive(white: Double, night: RGB) -> Color {
        #if canImport(UIKit)
        Color(UIColor { $0.userInterfaceStyle == .dark ? night.uiColor : UIColor(white: white, alpha: 1) })
        #else
        Color(white: white)
        #endif
    }

    private static func adaptiveDim() -> Color {
        #if canImport(UIKit)
        Color(UIColor {
            $0.userInterfaceStyle == .dark ? UIColor(white: 0, alpha: 0.45)
                : CrayonPalette.ink.uiColor.withAlphaComponent(0.35)
        })
        #else
        CrayonPalette.ink.color.opacity(0.35)
        #endif
    }
}

#if canImport(UIKit)
extension RGB {
    var uiColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: 1) }
}
#endif
