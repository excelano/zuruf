// TalkLink.swift
// Intents
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

// zuruf://talk?person=<id>&name=<name> opens the talk screen for a contact.
enum TalkLink {
    static func url(for recipient: Recipient) -> URL {
        var components = URLComponents()
        components.scheme = "zuruf"
        components.host = "talk"
        let (kind, id) = switch recipient {
        case .person(let id, _): ("person", id)
        case .group(let id, _): ("group", id)
        }
        components.queryItems = [
            URLQueryItem(name: kind, value: id),
            URLQueryItem(name: "name", value: recipient.name),
        ]
        return components.url!
    }

    static func recipient(from url: URL) -> Recipient? {
        guard url.scheme == "zuruf", url.host() == "talk",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let name = items.first(where: { $0.name == "name" })?.value else {
            return nil
        }
        if let id = items.first(where: { $0.name == "person" })?.value {
            return .person(id: id, name: name)
        }
        if let id = items.first(where: { $0.name == "group" })?.value {
            return .group(id: id, name: name)
        }
        return nil
    }
}
