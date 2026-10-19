// DemoMode.swift
// Zuruf
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

// Sample data for the App Store screenshots, shown when a Debug build is
// launched with --demo. Release builds never enter it.
enum DemoMode {
    static let isActive: Bool = {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--demo")
        #else
        false
        #endif
    }()

    static func has(_ flag: String) -> Bool {
        isActive && ProcessInfo.processInfo.arguments.contains(flag)
    }

    static let family = TalkGroup(id: "demo-family", name: "Family", memberIds: ["demo-me", "demo-mom", "demo-lena", "demo-max"])

    static let account = Account(
        serverURL: URL(string: "https://zuruf.example.com")!,
        serverID: "demo",
        userID: "demo-me",
        displayName: "Dad",
        token: "demo"
    )

    static let contacts = Contacts(
        users: [
            Person(id: "demo-echo", displayName: "Echo", isBot: true),
            Person(id: "demo-grandpa", displayName: "Grandpa", isBot: false),
            Person(id: "demo-lena", displayName: "Lena", isBot: false),
            Person(id: "demo-max", displayName: "Max", isBot: false),
            Person(id: "demo-mom", displayName: "Mom", isBot: false),
        ],
        groups: [family]
    )

    static var clips: ClipList {
        let now = Date()
        return ClipList(
            received: [
                ReceivedClip(id: "demo-1", senderId: "demo-mom", toGroup: nil, durationMs: 6_200,
                             createdAt: now.addingTimeInterval(-2 * 60), senderName: "Mom", groupName: nil, playedAt: nil),
                ReceivedClip(id: "demo-2", senderId: "demo-lena", toGroup: family.id, durationMs: 4_100,
                             createdAt: now.addingTimeInterval(-25 * 60), senderName: "Lena", groupName: family.name,
                             playedAt: now.addingTimeInterval(-20 * 60)),
                ReceivedClip(id: "demo-3", senderId: "demo-grandpa", toGroup: nil, durationMs: 11_800,
                             createdAt: now.addingTimeInterval(-3 * 3600), senderName: "Grandpa", groupName: nil,
                             playedAt: now.addingTimeInterval(-170 * 60)),
            ],
            sent: [
                SentClip(id: "demo-4", toUser: nil, toGroup: family.id, durationMs: 3_500,
                         createdAt: now.addingTimeInterval(-40 * 60),
                         playedBy: [
                             Receipt(userId: "demo-mom", playedAt: now.addingTimeInterval(-38 * 60)),
                             Receipt(userId: "demo-max", playedAt: now.addingTimeInterval(-30 * 60)),
                         ]),
            ]
        )
    }
}
