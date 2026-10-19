// TalkView.swift
// Zuruf
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI
import WatchKit

struct TalkView: View {
    let recipient: Recipient
    @EnvironmentObject private var model: AppModel
    @StateObject private var recorder = Recorder()
    @State private var isPressed = false
    @State private var micDenied = false

    var body: some View {
        VStack(spacing: 8) {
            Text(recipient.name)
                .font(.headline)
                .lineLimit(1)
            ZStack {
                Circle()
                    .fill(recorder.isRecording ? Color.red : Color.accentColor)
                Image(systemName: "mic.fill")
                    .font(.system(size: 36))
            }
            .scaleEffect(isPressed ? 0.94 : 1)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in press() }
                    .onEnded { _ in release() }
            )
            footer
        }
        .padding(.horizontal)
        .onAppear {
            recorder.onFinish = { file in
                WKInterfaceDevice.current().play(.stop)
                model.outbox.enqueue(file, to: recipient)
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
                .font(.footnote.monospacedDigit())
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
            do {
                try recorder.start()
                WKInterfaceDevice.current().play(.start)
            } catch {
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }

    private func release() {
        isPressed = false
        recorder.stop()
    }
}
