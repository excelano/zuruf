// Recorder.swift
// AppCore
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import AVFoundation

@MainActor
final class Recorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    static let maxDuration: TimeInterval = 60
    static let minDuration: TimeInterval = 0.5

    @Published private(set) var isRecording = false
    @Published private(set) var startedAt: Date?

    // Called with the finished file, also when the recording stops at the length limit.
    var onFinish: ((URL) -> Void)?
    private var recorder: AVAudioRecorder?

    static func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default)
        try session.setActive(true)
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        let recorder = try AVAudioRecorder(url: file, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 22_050,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 32_000,
        ])
        recorder.delegate = self
        guard recorder.record(forDuration: Self.maxDuration) else {
            throw NSError(domain: "Zuruf.Recorder", code: 1)
        }
        self.recorder = recorder
        isRecording = true
        startedAt = Date()
    }

    func stop() {
        recorder?.stop()
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        let file = recorder.url
        let duration = recorder.currentTime
        Task { @MainActor in
            let elapsed = startedAt.map { Date().timeIntervalSince($0) } ?? duration
            isRecording = false
            startedAt = nil
            self.recorder = nil
            try? AVAudioSession.sharedInstance().setActive(false)
            if flag && elapsed >= Self.minDuration {
                onFinish?(file)
            } else {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
