import KitArt
import SwiftUI

/// One home panel row (spec "Now and next on home", the "Row shape" in "Home panel lines", layout
/// v73 look B): the picture 80 on the left, then 16 to its right two lines: "{caption} · {title}"
/// (body bold, one line) on the picture's top + 37 and the time line (caption `softText`, one line)
/// on + 68. Every Now, Next and Tomorrow row on home. The words come from the caller's State; the
/// part joins caption and title with its separator. A long line ends with "…" inside the panel (text
/// column 312, to 1336). At night the picture sits on an 80 plate (picture 56).
public struct NextRow: View {
    private let picture: KitSlot
    private let caption: String
    private let title: String
    private let line: String?
    private let showsStar: Bool
    private let look: KidLook
    @Environment(\.sizing) private var sizing

    /// `line` nil: the row has no time line (Kid B with nothing later today).
    public init(picture: KitSlot, caption: String, title: String, line: String?, showsStar: Bool = false,
                look: KidLook = .day) {
        self.picture = picture
        self.caption = caption
        self.title = title
        self.line = line
        self.showsStar = showsStar
        self.look = look
    }

    /// The row's box on the board: the panel's width (928–1336) and the picture's height.
    public static let boardSize = CGSize(width: 408, height: 80)
    /// The lines below, in board points from the row's top-left; screen layouts place the row from them.
    public static let pictureSide: CGFloat = 80
    /// Text left: the picture plus the 16 gap (x 1024 on the panel).
    public static let textLeft: CGFloat = 96
    public static let titleBaseline: CGFloat = 37
    public static let lineBaseline: CGFloat = 68
    /// Between the caption and the title.
    private static let separator = " · " // copy-ok: a separator

    public var body: some View {
        let side = sizing(Self.pictureSide)
        let textWidth = sizing(Self.boardSize.width - Self.textLeft)
        ZStack(alignment: .topLeading) {
            KitPlate(look: look, size: side, nightPicture: 56.0 / 80.0) {
                KitIcon(picture, size: side)
                    .overlay(alignment: .topTrailing) {
                        // A just-once item keeps its star sticker (28) on the picture.
                        if showsStar { KitIcon(.star, size: sizing(28)) }
                    }
            }
            .place(topLeft: .zero)
            text(Text(caption + Self.separator + title).crayonType(.body, bold: true), color: look.ink, width: textWidth,
                 baseline: Self.titleBaseline)
            if let line {
                text(Text(line).crayonType(.caption), color: look.softText, width: textWidth, baseline: Self.lineBaseline)
            }
        }
        .frame(width: sizing(Self.boardSize.width), height: sizing(Self.boardSize.height), alignment: .topLeading)
    }

    /// One line, capped at the text column so a long one ends with "…" (no `fixedSize` past 1336).
    private func text(_ text: some View, color: Color, width: CGFloat, baseline: CGFloat) -> some View {
        text.foregroundStyle(color).lineLimit(1).truncationMode(.tail)
            .frame(width: width, alignment: .leading)
            .place(left: sizing(Self.textLeft), baseline: sizing(baseline))
    }
}
