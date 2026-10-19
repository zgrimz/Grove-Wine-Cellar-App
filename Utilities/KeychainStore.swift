import Foundation
import os
import Security

/// Minimal Keychain wrapper for the AI providers' API keys — one item per provider, keyed by
/// `AIProvider.keychainAccount`.
///
/// Secrets must not live in `UserDefaults` (plain text, backed up, readable). Items here are stored
/// `AfterFirstUnlockThisDeviceOnly`: encrypted on the device, never synced, and not carried to
/// another phone by a backup restore.
///
/// **Do not add `kSecAttrService` to these queries.** Generic-password identity is
/// (service, account), so a service-qualified query would match none of the items already stored
/// and every existing user's key would silently disappear. Distinct account strings already keep
/// each provider's key apart.
enum KeychainStore {
    /// Store (or clear, when `value` is empty) a string under `key`.
    static func set(_ value: String, for key: String) {
        guard !value.isEmpty else {
            delete(key)
            return
        }
        let data = Data(value.utf8)
        let status = SecItemUpdate(query(for: key) as CFDictionary,
                                   [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var add = query(for: key)
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            log(SecItemAdd(add as CFDictionary, nil), "store the key for \(key)")
        } else {
            log(status, "update the key for \(key)")
        }
    }

    /// Read the string stored under `key`, or nil if absent.
    static func get(_ key: String) -> String? {
        var lookup = query(for: key)
        lookup[kSecReturnData as String] = true
        lookup[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else {
            log(status, "read the key for \(key)")
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    // MARK: Private

    private static func query(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
    }

    private static func delete(_ key: String) {
        log(SecItemDelete(query(for: key) as CFDictionary), "clear the key for \(key)")
    }

    /// A discarded `OSStatus` is how a failed write presents: a key that appears to save, because
    /// the typed value lives in `AISettings` for the rest of the session, and is gone by the next
    /// launch. `errSecItemNotFound` is ordinary — there was nothing to read or remove.
    private static func log(_ status: OSStatus, _ action: String) {
        guard status != errSecSuccess, status != errSecItemNotFound else { return }
        let detail = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
        Logger.keychain.error("Keychain couldn't \(action, privacy: .public) — \(detail, privacy: .public) (\(status, privacy: .public))")
    }
}
