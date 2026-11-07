import CoreText
import Synchronization
import UIKit

/// Registers Playpen Sans (one variable font) with Core Text and builds fonts at the
/// design's weights by setting the `wght` axis directly.
public enum FontRegistrar {
    public static let familyName = "Playpen Sans"

    private static let fileName = "PlaypenSans[wght]"
    private static let weightAxis = 0x7767_6874 // 'wght'
    private static let state = Mutex<String?>(nil) // PostScript name once registered

    /// Registers the font for this process. Safe to call more than once; true when available.
    @discardableResult
    public static func registerAll() -> Bool {
        state.withLock { name in
            if name != nil { return true }
            guard let url = ResourceLocator.bundle(named: "DesignSystemResources")?
                .url(forResource: fileName, withExtension: "ttf") else { return false }
            var error: Unmanaged<CFError>?
            let ok = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            let alreadyRegistered = (error?.takeRetainedValue()).map {
                CFErrorGetCode($0) == CTFontManagerError.alreadyRegistered.rawValue
            } ?? false
            guard ok || alreadyRegistered,
                  let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
                  let first = descriptors.first,
                  let psName = CTFontDescriptorCopyAttribute(first, kCTFontNameAttribute) as? String
            else { return false }
            name = psName
            return true
        }
    }

    /// The PostScript name of the registered font (nil before registration).
    public static var postScriptName: String {
        state.withLock { $0 } ?? familyName
    }

    /// Playpen Sans at `size` and `weight` (falls back to the rounded system font if missing).
    public static func font(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        guard registerAll(), let base = UIFont(name: postScriptName, size: size) else {
            return .systemFont(ofSize: size, weight: weight)
        }
        let wght = wghtValue(for: weight)
        let descriptor = base.fontDescriptor.addingAttributes([
            UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String): [weightAxis: wght],
        ])
        return UIFont(descriptor: descriptor, size: size)
    }

    private static func wghtValue(for weight: UIFont.Weight) -> CGFloat {
        switch weight {
        case .bold, .heavy, .black: 700
        case .semibold: 600
        default: 500
        }
    }
}
