// NotificationController.swift
// Zuruf
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import AVFoundation
import SwiftUI
import UserNotifications
import WatchKit

final class NotificationController: WKUserNotificationHostingController<NotificationView> {
    private var content: UNNotificationContent?

    override class var isInteractive: Bool { true }

    override var body: NotificationView {
        NotificationView(content: content)
    }

    override func didReceive(_ notification: UNNotification) {
        content = notification.request.content
    }
}

struct NotificationView: View {
    // Long enough for the notification sound to finish, so it does not duck the clip.
    private static let autoplayDelay: Duration = .seconds(1.5)

    let content: UNNotificationContent?
    @AppStorage(ClipNotification.playAutomaticallyKey) private var playAutomatically = true
    @ObservedObject private var player = ClipPlayer.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(content?.title ?? "")
                .font(.headline)
            Text(content?.body ?? "")
                .font(.footnote)
            if let clipID {
                Button {
                    play(clipID, category: .playback)
                } label: {
                    Label(player.loadingClipID == clipID ? "Loading…" : "Play", systemImage: "play.fill")
                }
            }
        }
        .task {
            guard let clipID, playAutomatically, ClipNotification.claimAutoplay(of: clipID) else { return }
            try? await Task.sleep(for: Self.autoplayDelay)
            play(clipID, category: .ambient)
        }
    }

    private var clipID: String? {
        content.flatMap(ClipNotification.clipID(in:))
    }

    private func play(_ clipID: String, category: AVAudioSession.Category) {
        player.play(clipID: clipID, attachment: content?.attachments.first?.url, category: category)
    }
}
