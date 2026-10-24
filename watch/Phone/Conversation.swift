// Conversation.swift
// Phone
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

// One clip in a conversation with a person or group, in the order sent.
enum ConversationItem: Identifiable {
    case received(ReceivedClip)
    case sent(SentClip)

    var id: String {
        switch self {
        case .received(let clip): clip.id
        case .sent(let clip): clip.id
        }
    }

    var createdAt: Date {
        switch self {
        case .received(let clip): clip.createdAt
        case .sent(let clip): clip.createdAt
        }
    }
}

extension ClipList {
    func conversation(with recipient: Recipient) -> [ConversationItem] {
        let items = received.filter { $0.belongs(to: recipient) }.map(ConversationItem.received)
            + sent.filter { $0.belongs(to: recipient) }.map(ConversationItem.sent)
        return items.sorted { $0.createdAt < $1.createdAt }
    }

    func unplayedCount(from recipient: Recipient) -> Int {
        received.filter { $0.belongs(to: recipient) && $0.playedAt == nil }.count
    }

    func lastActivity(with recipient: Recipient) -> Date? {
        let dates = received.filter { $0.belongs(to: recipient) }.map(\.createdAt)
            + sent.filter { $0.belongs(to: recipient) }.map(\.createdAt)
        return dates.max()
    }
}

private extension ReceivedClip {
    func belongs(to recipient: Recipient) -> Bool {
        switch recipient {
        case .person(let id, _): toGroup == nil && senderId == id
        case .group(let id, _): toGroup == id
        }
    }
}

private extension SentClip {
    func belongs(to recipient: Recipient) -> Bool {
        switch recipient {
        case .person(let id, _): toGroup == nil && toUser == id
        case .group(let id, _): toGroup == id
        }
    }
}
