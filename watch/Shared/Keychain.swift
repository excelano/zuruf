// Keychain.swift
// Shared
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Security

// Items live in the Keychain access group that the app and its extensions
// share, which is the first group in their keychain-access-groups entitlement
// and so the default for these queries.
enum Keychain {
    private static func query(_ service: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "default",
        ]
    }

    static func data(_ service: String) -> Data? {
        var item: CFTypeRef?
        var search = query(service)
        search[kSecReturnData as String] = true
        guard SecItemCopyMatching(search as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    static func set(_ data: Data, for service: String) throws {
        delete(service)
        var item = query(service)
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    static func delete(_ service: String) {
        SecItemDelete(query(service) as CFDictionary)
    }
}
