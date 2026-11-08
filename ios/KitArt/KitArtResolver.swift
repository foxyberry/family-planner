import SwiftUI
import UIKit

/// Picks the picture for a slot. Today every slot shows its kit picture (v0); later a child's
/// own drawing can replace it by swapping the resolver in the environment.
public protocol KitArtResolving: Sendable {
    func image(for slot: KitSlot) -> Image
}

/// The bundled kit pictures, preferring a local private override when one is present.
/// Pass `includePrivate: false` wherever the result can be published (snapshot baselines).
public struct BundledKitArt: KitArtResolving {
    public enum Source: Equatable, Sendable { case `private`, `public`, missing }

    public let includePrivate: Bool

    public init(includePrivate: Bool = true) {
        self.includePrivate = includePrivate
    }

    /// Which catalog `image(for:)` uses for `slot`.
    public func source(for slot: KitSlot) -> Source {
        if includePrivate, Self.privateImage(for: slot) != nil { return .private }
        if Self.publicImage(for: slot) != nil { return .public }
        return .missing
    }

    public func image(for slot: KitSlot) -> Image {
        // SwiftUI's named-image initializer keeps the catalog's vector data; Image(uiImage:)
        // would rasterize at the asset's natural size and blur when scaled up.
        switch source(for: slot) {
        case .private: Self.privateBundle.map { Image(slot.rawValue, bundle: $0) } ?? Self.placeholder
        case .public: Self.publicBundle.map { Image(slot.rawValue, bundle: $0) } ?? Self.placeholder
        case .missing: Self.placeholder
        }
    }

    private static var placeholder: Image { Image(systemName: "questionmark.square.dashed") }

    /// The public kit picture for `slot`, if the catalog has it.
    public static func publicImage(for slot: KitSlot) -> UIImage? {
        publicBundle.flatMap { UIImage(named: slot.rawValue, in: $0, with: nil) }
    }

    static func privateImage(for slot: KitSlot) -> UIImage? {
        privateBundle.flatMap { UIImage(named: slot.rawValue, in: $0, with: nil) }
    }

    private static let publicBundle = resourceBundle(named: "KitArtResources") // copy-ok: bundle name
    private static let privateBundle = resourceBundle(named: "KitArtPrivateResources") // copy-ok: bundle name

    /// Resource bundles sit next to this module's code: inside the app, or inside a test bundle.
    private static func resourceBundle(named name: String) -> Bundle? {
        let home = Bundle(for: BundleToken.self)
        return [home, .main].lazy
            .compactMap { $0.url(forResource: name, withExtension: "bundle") }
            .compactMap(Bundle.init(url:))
            .first
    }
}

private final class BundleToken {}

private struct KitArtKey: EnvironmentKey {
    static let defaultValue: any KitArtResolving = BundledKitArt()
}

extension EnvironmentValues {
    /// Where `KitIcon` gets its pictures.
    public var kitArt: any KitArtResolving {
        get { self[KitArtKey.self] }
        set { self[KitArtKey.self] = newValue }
    }
}
