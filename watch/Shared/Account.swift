// Account.swift
// Shared
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

struct Account: Codable, Equatable {
    let serverURL: URL
    let serverID: String
    let userID: String
    let displayName: String
    let token: String
}

enum AccountStore {
    private static let service = "zuruf.account"

    static func load() -> Account? {
        Keychain.data(service).flatMap { try? JSONDecoder().decode(Account.self, from: $0) }
    }

    static func save(_ account: Account) throws {
        try Keychain.set(JSONEncoder().encode(account), for: service)
    }

    static func delete() {
        Keychain.delete(service)
    }
}
