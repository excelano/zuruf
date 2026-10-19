// LastRecipient.swift
// Shared
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

// The person or group most recently sent a clip, which the complication opens.
enum LastRecipient {
    private static let service = "zuruf.lastRecipient"

    static func load() -> Recipient? {
        Keychain.data(service).flatMap { try? JSONDecoder().decode(Recipient.self, from: $0) }
    }

    static func save(_ recipient: Recipient) {
        try? Keychain.set(JSONEncoder().encode(recipient), for: service)
    }

    static func clear() {
        Keychain.delete(service)
    }
}
