// ConversationView.swift
// Phone
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct ConversationView: View {
    let recipient: Recipient
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var outbox = AppModel.shared.outbox

    private var items: [ConversationItem] {
        model.clips?.conversation(with: recipient) ?? []
    }

    private var pending: [Outbox.Item] {
        outbox.items.filter { $0.recipient == recipient }
    }

    private var isGroup: Bool {
        if case .group = recipient { true } else { false }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(items) { item in
                    switch item {
                    case .received(let clip):
                        ReceivedBubble(clip: clip, showsSender: isGroup)
                    case .sent(let clip):
                        SentBubble(clip: clip, isGroup: isGroup)
                    }
                }
                ForEach(pending) { _ in
                    PendingBubble()
                }
            }
            .padding()
        }
        .defaultScrollAnchor(.bottom)
        .overlay {
            if items.isEmpty && pending.isEmpty {
                Text("No messages")
                    .foregroundStyle(.secondary)
            }
        }
        .safeAreaInset(edge: .bottom) {
            TalkBar(recipient: recipient)
        }
        .navigationTitle(recipient.name)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await model.refresh()
        }
    }
}

private struct ReceivedBubble: View {
    let clip: ReceivedClip
    let showsSender: Bool
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if showsSender {
                    Text(clip.senderName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 10) {
                    PlayButton(clipID: clip.id)
                    Text(clipLength(clip.durationMs))
                        .monospacedDigit()
                    if clip.playedAt == nil {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18))
                Text(clipTime(clip.createdAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 60)
        }
        .contextMenu {
            if clip.playedAt == nil {
                Button("Mark as Read", systemImage: "envelope.open") {
                    Task { await model.markPlayed(clip.id) }
                }
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                Task { await model.deleteClip(clip.id) }
            }
        }
    }
}

private struct PlayButton: View {
    let clipID: String
    @ObservedObject private var player = ClipPlayer.shared

    var body: some View {
        if player.loadingClipID == clipID {
            ProgressView()
                .frame(width: 28, height: 28)
        } else if player.playingClipID == clipID {
            Button("Stop", systemImage: "stop.circle.fill") {
                player.stop()
            }
            .labelStyle(.iconOnly)
            .font(.title)
        } else {
            Button("Play", systemImage: "play.circle.fill") {
                player.play(clipID: clipID, attachment: nil, category: .playback)
            }
            .labelStyle(.iconOnly)
            .font(.title)
        }
    }
}

private struct SentBubble: View {
    let clip: SentClip
    let isGroup: Bool
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack {
            Spacer(minLength: 60)
            VStack(alignment: .trailing, spacing: 4) {
                OutgoingShape(text: clipLength(clip.durationMs))
                Text("\(clipTime(clip.createdAt)) · \(playedSummary)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var playedSummary: String {
        guard isGroup else {
            return clip.playedBy.isEmpty ? "Not played yet" : "Played"
        }
        let names = clip.playedBy.compactMap { model.contacts?.name(ofUser: $0.userId) }
        return names.isEmpty ? "Not played yet" : "Played by " + names.formatted(.list(type: .and))
    }
}

private struct PendingBubble: View {
    var body: some View {
        HStack {
            Spacer(minLength: 60)
            VStack(alignment: .trailing, spacing: 4) {
                OutgoingShape(text: "Sending…")
                    .opacity(0.6)
                Text("Waiting to send")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct OutgoingShape: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "mic.fill")
            .monospacedDigit()
            .foregroundStyle(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct TalkBar: View {
    let recipient: Recipient
    @EnvironmentObject private var model: AppModel
    @StateObject private var recorder = Recorder()
    @State private var isPressed = false
    @State private var micDenied = false

    var body: some View {
        VStack(spacing: 6) {
            footer
            ZStack {
                if recorder.isRecording {
                    Ripples(spread: 2.2)
                }
                Circle()
                    .fill(recorder.isRecording ? Color.blue : Color.accentColor)
                Image(systemName: "mic.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(recorder.isRecording ? Color.white : Color.black)
            }
            .frame(width: 76, height: 76)
            .scaleEffect(isPressed ? 0.94 : 1)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in press() }
                    .onEnded { _ in release() }
            )
            .accessibilityLabel("Hold to talk")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.bar)
        .sensoryFeedback(trigger: recorder.isRecording) { _, isRecording in
            isRecording ? .start : .stop
        }
        .onAppear {
            recorder.onFinish = { file in
                model.send(file, to: recipient)
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        if micDenied {
            Text("Allow the microphone in Settings")
                .font(.footnote)
                .foregroundStyle(.red)
        } else if let startedAt = recorder.startedAt {
            Text(timerInterval: startedAt...startedAt.addingTimeInterval(Recorder.maxDuration), countsDown: false)
                .font(.title3.bold().monospacedDigit())
        } else {
            Text("Hold to talk")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func press() {
        guard !isPressed else { return }
        isPressed = true
        Task {
            guard await Recorder.requestPermission() else {
                micDenied = true
                return
            }
            guard isPressed else { return }
            ClipPlayer.shared.stop()
            try? recorder.start()
        }
    }

    private func release() {
        isPressed = false
        recorder.stop()
    }
}

private func clipLength(_ durationMs: Int) -> String {
    Duration.milliseconds(durationMs).formatted(.time(pattern: .minuteSecond))
}

// Clips last seven days, so a weekday tells older ones apart.
private func clipTime(_ date: Date) -> String {
    Calendar.current.isDateInToday(date)
        ? date.formatted(.dateTime.hour().minute())
        : date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
}
