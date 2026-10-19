// Models.swift
// Shared
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

struct Person: Decodable, Identifiable, Hashable {
    let id: String
    let displayName: String
    let isBot: Bool
}

struct TalkGroup: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let memberIds: [String]
}

struct Contacts: Decodable {
    let users: [Person]
    let groups: [TalkGroup]

    func name(ofUser id: String) -> String? {
        users.first { $0.id == id }?.displayName
    }

    func name(ofGroup id: String) -> String? {
        groups.first { $0.id == id }?.name
    }
}

enum Recipient: Codable, Hashable {
    case person(id: String, name: String)
    case group(id: String, name: String)

    var name: String {
        switch self {
        case .person(_, let name), .group(_, let name): name
        }
    }
}

struct ReceivedClip: Decodable, Identifiable, Hashable {
    let id: String
    let senderId: String
    let toGroup: String?
    let durationMs: Int
    let createdAt: Date
    let senderName: String
    let groupName: String?
    let playedAt: Date?

    var replyRecipient: Recipient {
        if let toGroup, let groupName {
            return .group(id: toGroup, name: groupName)
        }
        return .person(id: senderId, name: senderName)
    }
}

struct Receipt: Decodable, Hashable {
    let userId: String
    let playedAt: Date
}

struct SentClip: Decodable, Identifiable, Hashable {
    let id: String
    let toUser: String?
    let toGroup: String?
    let durationMs: Int
    let createdAt: Date
    let playedBy: [Receipt]
}

struct ClipList: Decodable {
    let received: [ReceivedClip]
    let sent: [SentClip]
}
