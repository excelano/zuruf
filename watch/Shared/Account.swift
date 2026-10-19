// Account.swift
// Shared
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import Security

struct Account: Codable, Equatable {
    let serverURL: URL
    let serverID: String
    let userID: String
    let displayName: String
    let token: String
}

// The account lives in the Keychain access group that the app and the
// notification service extension share, which is the first group in their
// keychain-access-groups entitlement and so the default for these queries.
enum AccountStore {
    private static let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "zuruf.account",
        kSecAttrAccount as String: "default",
    ]

    static func load() -> Account? {
        var item: CFTypeRef?
        var search = query
        search[kSecReturnData as String] = true
        guard SecItemCopyMatching(search as CFDictionary, &item) == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return try? JSONDecoder().decode(Account.self, from: data)
    }

    static func save(_ account: Account) throws {
        delete()
        var item = query
        item[kSecValueData as String] = try JSONEncoder().encode(account)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
    }
}
