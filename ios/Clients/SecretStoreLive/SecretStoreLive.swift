import Foundation
import Security
import SecretStore

extension SecretStore {
    /// Generic passwords in this app's Keychain, readable only while the iPad is unlocked and never
    /// synced or backed up to another device.
    public static let live = live(busKey: nil)

    /// The Keychain first, then the LTA key built into this app (the family's git-ignored local
    /// config), so a grown-up only types a key in C2 to change it.
    public static func live(busKey: String?) -> Self {
        let keychain = keychainStore
        return Self(read: { name in await keychain.read(name) ?? (name == .busKey ? busKey : nil) },
                    write: keychain.write)
    }

    private static let keychainStore = Self(
        read: { name in
            var result: AnyObject?
            let query = Self.query(name).merging([kSecReturnData as String: true,
                                                  kSecMatchLimit as String: kSecMatchLimitOne]) { $1 }
            guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
                  let data = result as? Data else { return nil }
            return String(data: data, encoding: .utf8)
        },
        write: { name, value in
            SecItemDelete(Self.query(name) as CFDictionary)
            guard let value, !value.isEmpty else { return }
            let item = Self.query(name).merging([
                kSecValueData as String: Data(value.utf8),
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            ]) { $1 }
            let status = SecItemAdd(item as CFDictionary, nil)
            guard status == errSecSuccess else { throw SecretStoreError(status: status) }
        }
    )

    private static func query(_ name: SecretName) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: "family-planner", // copy-ok: keychain service name
         kSecAttrAccount as String: name.rawValue]
    }
}

public struct SecretStoreError: Error, Equatable {
    public let status: OSStatus
}
