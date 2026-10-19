// ContactsCache.swift
// Intents
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

// The app's last contact list, shared with the widget so it can offer
// contacts without a network call.
enum ContactsCache {
    private static let service = "zuruf.contacts"

    static func load() -> [Recipient] {
        Keychain.data(service).flatMap { try? JSONDecoder().decode([Recipient].self, from: $0) } ?? []
    }

    // Returns whether the stored list changed.
    @discardableResult
    static func save(_ recipients: [Recipient]) -> Bool {
        guard recipients != load(), let data = try? JSONEncoder().encode(recipients) else { return false }
        try? Keychain.set(data, for: service)
        return true
    }

    static func clear() {
        Keychain.delete(service)
    }
}
