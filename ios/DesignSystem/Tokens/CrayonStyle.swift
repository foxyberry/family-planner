import CrayonKit
import SwiftUI

/// Shared crayon fills and fixed seeds, so every instance of a part looks the same.
/// Lists add their index to the seed so neighbours differ.
public enum CrayonStyle {
    public static let skyPill = CrayonFill(color: CrayonColor.nowSky, hachure: HachureStyle(degrees: -30))
    public static let yellowSlider = CrayonFill(color: CrayonColor.goYellow, hachure: HachureStyle(degrees: -50))
    public static let apricot = CrayonFill(color: CrayonColor.kidApricot, hachure: HachureStyle(degrees: -35))
    public static let blueCrayon = CrayonFill(color: CrayonColor.kidABlue, hachure: HachureStyle(degrees: -40))
    public static let doneGreen = CrayonFill(color: CrayonColor.doneGreen, hachure: HachureStyle(degrees: -50))
    public static let ink = CrayonFill(color: CrayonColor.marker, hachure: nil)
    public static let paper = CrayonFill.paper(CrayonColor.card)

    enum Seed {
        static let inkButton: UInt32 = 101
        static let kidPill: UInt32 = 201
        static let roundButton: UInt32 = 301
        static let checkMark: UInt32 = 401
        static let tabs: UInt32 = 501
        static let dayChip: UInt32 = 601
        static let dateChip: UInt32 = 701
        static let field: UInt32 = 801
        static let iconPicker: UInt32 = 901
        static let slider: UInt32 = 1001
        static let card: UInt32 = 1101
        static let nowRow: UInt32 = 1201
        static let bubble: UInt32 = 1301
        static let league: UInt32 = 1401
        static let voice: UInt32 = 1501
        static let kidFace: UInt32 = 1601
    }
}
