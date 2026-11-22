import KitArt
import SwiftUI

/// One home panel row (spec "Now and next on home", the "Next shape" in "Home panel lines"): the
/// picture 104 on the left, then 16 to its right the caption ("Now" / "Next", caption `softText`),
/// the title (head, one line) and the time line (body `softText`, one line), on baselines 21, 62 and
/// 100 below the picture's top. Kid A's Next row and Kid B's Now and Next rows (layout v68).
/// The words come from the caller's State. A long title or line ends with "…" inside the panel
/// (text column 288, to 1336). At night the picture sits on a 104 plate (picture 64, board A1n).
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
    public static let boardSize = CGSize(width: 408, height: 104)
    /// The lines below, in board points from the row's top-left; screen layouts place the row from them.
    public static let pictureSide: CGFloat = 104
    /// Text left: the picture plus the 16 gap.
    public static let textLeft: CGFloat = 120
    public static let captionBaseline: CGFloat = 21
    public static let titleBaseline: CGFloat = 62
    public static let lineBaseline: CGFloat = 100

    public var body: some View {
        let side = sizing(Self.pictureSide)
        let textWidth = sizing(Self.boardSize.width - Self.textLeft)
        ZStack(alignment: .topLeading) {
            KitPlate(look: look, size: side) {
                KitIcon(picture, size: side)
                    .overlay(alignment: .topTrailing) {
                        // A just-once item keeps its star sticker (36) on the picture.
                        if showsStar { KitIcon(.star, size: sizing(36)) }
                    }
            }
            .place(topLeft: .zero)
            text(Text(caption).crayonType(.caption), color: look.softText, width: textWidth,
                 baseline: Self.captionBaseline)
            text(Text(title).crayonType(.head), color: look.ink, width: textWidth, baseline: Self.titleBaseline)
            if let line {
                text(Text(line).crayonType(.body), color: look.softText, width: textWidth, baseline: Self.lineBaseline)
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
