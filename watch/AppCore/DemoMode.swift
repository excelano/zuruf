// DemoMode.swift
// AppCore
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

    static let crew = TalkGroup(id: "demo-crew", name: "Trail Crew", memberIds: ["demo-me", "demo-anna", "demo-ben", "demo-dana"])

    static let account = Account(
        serverURL: URL(string: "https://zuruf.example.com")!,
        serverID: "demo",
        userID: "demo-me",
        displayName: "Sam",
        token: "demo"
    )

    static let contacts = Contacts(
        users: [
            Person(id: "demo-echo", displayName: "Echo", isBot: true),
            Person(id: "demo-anna", displayName: "Anna", isBot: false),
            Person(id: "demo-ben", displayName: "Ben", isBot: false),
            Person(id: "demo-chris", displayName: "Chris", isBot: false),
            Person(id: "demo-dana", displayName: "Dana", isBot: false),
        ],
        groups: [crew]
    )

    // What the phone shows as each clip's transcript.
    static let transcripts = [
        "demo-1": "Are you still up for coffee after the hike?",
        "demo-2": "Trailhead lot is full. I'm parked on the shoulder just past the gate.",
        "demo-3": "Your package came. I left it on the porch, behind the bench.",
        "demo-4": "Got it. We'll meet you at the gate in ten.",
        "demo-5": "Ranger says the upper loop is closed today. Lower loop instead?",
        "demo-6": "Lower loop works. Start without me if I'm late.",
    ]

    static var clips: ClipList {
        let now = Date()
        return ClipList(
            received: [
                ReceivedClip(id: "demo-1", senderId: "demo-anna", toGroup: nil, durationMs: 6_200,
                             createdAt: now.addingTimeInterval(-2 * 60), senderName: "Anna", groupName: nil, playedAt: nil),
                ReceivedClip(id: "demo-5", senderId: "demo-dana", toGroup: crew.id, durationMs: 5_300,
                             createdAt: now.addingTimeInterval(-8 * 60), senderName: "Dana", groupName: crew.name, playedAt: nil),
                ReceivedClip(id: "demo-2", senderId: "demo-ben", toGroup: crew.id, durationMs: 4_100,
                             createdAt: now.addingTimeInterval(-45 * 60), senderName: "Ben", groupName: crew.name,
                             playedAt: now.addingTimeInterval(-43 * 60)),
                ReceivedClip(id: "demo-3", senderId: "demo-chris", toGroup: nil, durationMs: 11_800,
                             createdAt: now.addingTimeInterval(-3 * 3600), senderName: "Chris", groupName: nil,
                             playedAt: now.addingTimeInterval(-170 * 60)),
            ],
            sent: [
                SentClip(id: "demo-6", toUser: nil, toGroup: crew.id, durationMs: 2_900,
                         createdAt: now.addingTimeInterval(-5 * 60),
                         playedBy: [Receipt(userId: "demo-ben", playedAt: now.addingTimeInterval(-4 * 60))]),
                SentClip(id: "demo-4", toUser: nil, toGroup: crew.id, durationMs: 3_500,
                         createdAt: now.addingTimeInterval(-40 * 60),
                         playedBy: [
                             Receipt(userId: "demo-anna", playedAt: now.addingTimeInterval(-38 * 60)),
                             Receipt(userId: "demo-dana", playedAt: now.addingTimeInterval(-30 * 60)),
                         ]),
            ]
        )
    }
}
