// ClipPlayer.swift
// AppCore
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import AVFoundation

// Autoplay uses .ambient, which silent mode mutes, so a watch on silent falls
// back to the Play button; an explicit play uses .playback, which it does not.
@MainActor
final class ClipPlayer: ObservableObject {
    static let shared = ClipPlayer()

    @Published private(set) var playingClipID: String?
    @Published private(set) var loadingClipID: String?
    private var player: AVAudioPlayer?

    // An explicit play counts as heard and posts the played receipt; an
    // autoplay cannot know whether it was heard, so it does not.
    func play(clipID: String, attachment: URL?, category: AVAudioSession.Category) {
        Task {
            guard let data = await audio(clipID: clipID, attachment: attachment) else { return }
            do {
                try start(data, category: category)
                playingClipID = clipID
                if category == .playback {
                    await AppModel.shared.markPlayed(clipID)
                }
            } catch {
                playingClipID = nil
            }
        }
    }

    func stop() {
        player?.stop()
        playingClipID = nil
    }

    private func audio(clipID: String, attachment: URL?) async -> Data? {
        if let attachment {
            let scoped = attachment.startAccessingSecurityScopedResource()
            defer { if scoped { attachment.stopAccessingSecurityScopedResource() } }
            if let data = try? Data(contentsOf: attachment) {
                return data
            }
        }
        loadingClipID = clipID
        defer { loadingClipID = nil }
        return try? await AppModel.shared.api?.audio(clipID: clipID)
    }

    private func start(_ data: Data, category: AVAudioSession.Category) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(category, mode: .default, policy: .default)
        try session.setActive(true)
        let player = try AVAudioPlayer(data: data)
        self.player = player
        player.play()
    }
}
