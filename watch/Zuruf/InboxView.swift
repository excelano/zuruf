// InboxView.swift
// Zuruf
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct InboxView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List {
            if let received = model.clips?.received, !received.isEmpty {
                Section("Received") {
                    ForEach(received) { clip in
                        NavigationLink {
                            ClipView(clip: clip)
                        } label: {
                            ReceivedRow(clip: clip)
                        }
                    }
                }
            }
            if let sent = model.clips?.sent, !sent.isEmpty {
                Section("Sent") {
                    ForEach(sent) { clip in
                        SentRow(clip: clip)
                    }
                }
            }
            if model.clips.map({ $0.received.isEmpty && $0.sent.isEmpty }) ?? true {
                Text("No messages")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Inbox")
        .refreshable {
            await model.refresh()
        }
    }
}

private struct ReceivedRow: View {
    let clip: ReceivedClip

    var body: some View {
        HStack {
            Circle()
                .fill(clip.playedAt == nil ? Color.accentColor : .clear)
                .frame(width: 6, height: 6)
            VStack(alignment: .leading) {
                Text(clip.senderName)
                if let groupName = clip.groupName {
                    Text(groupName)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text(clip.createdAt, style: .relative)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SentRow: View {
    let clip: SentClip
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading) {
            Text("To \(model.recipientName(of: clip))")
            Text(playedSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var playedSummary: String {
        let names = clip.playedBy.compactMap { model.contacts?.name(ofUser: $0.userId) }
        return names.isEmpty ? "Not played yet" : "Played by " + names.formatted(.list(type: .and))
    }
}

struct ClipView: View {
    let clip: ReceivedClip
    @ObservedObject private var player = ClipPlayer.shared

    var body: some View {
        VStack(spacing: 10) {
            Text(clip.senderName)
                .font(.headline)
            Text(Duration.milliseconds(clip.durationMs), format: .time(pattern: .minuteSecond))
                .foregroundStyle(.secondary)
            Button {
                player.play(clipID: clip.id, attachment: nil, category: .playback)
            } label: {
                Label(player.loadingClipID == clip.id ? "Loading…" : "Play", systemImage: "play.fill")
            }
            NavigationLink(value: clip.replyRecipient) {
                Label("Reply", systemImage: "mic.fill")
            }
        }
    }
}
