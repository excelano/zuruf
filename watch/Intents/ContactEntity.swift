// ContactEntity.swift
// Intents
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import AppIntents

struct ContactEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Contact"
    static let defaultQuery = ContactQuery()

    let recipient: Recipient

    var id: String {
        switch recipient {
        case .person(let id, _): "person:\(id)"
        case .group(let id, _): "group:\(id)"
        }
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(recipient.name)")
    }
}

struct ContactQuery: EntityQuery {
    func entities(for identifiers: [ContactEntity.ID]) async throws -> [ContactEntity] {
        try await suggestedEntities().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [ContactEntity] {
        ContactsCache.load().map(ContactEntity.init)
    }
}
