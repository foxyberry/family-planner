import CoreGraphics

/// Spacing steps (board 00): 4 · 8 · 12 · 16 · 24 · 40 · 64. `xxs` (4) and `sm` (12) are for the
/// inside of one part only (icon to label, chip padding, a caption under a picture); between parts
/// use 16 or more. No other gaps.
public enum Spacing {
    public static let xxs: CGFloat = 4
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let s: CGFloat = 16
    public static let m: CGFloat = 24
    public static let l: CGFloat = 40
    public static let xl: CGFloat = 64
}
