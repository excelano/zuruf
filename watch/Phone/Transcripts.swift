// Transcripts.swift
// Phone
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import AVFoundation
import Speech

// Transcripts of sent and received clips, made on this phone in its own
// language and kept only here, keyed by clip.
@MainActor
final class Transcripts: ObservableObject {
    static let shared = Transcripts()

    @Published private(set) var texts: [String: String]
    @Published private(set) var transcribingClipID: String?
    private var queue: [String] = []
    private var failed: Set<String> = []
    private let fileURL = URL.applicationSupportDirectory.appending(path: "transcripts.json")

    init() {
        texts = (try? Data(contentsOf: fileURL)).flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
    }

    // Transcribes the clips that have none yet, newest first, one at a time,
    // and drops the transcripts of clips that are gone from the server. A clip
    // that fails is tried again the next time the app launches.
    func update(for clips: ClipList) {
        let dated = clips.received.map { ($0.id, $0.createdAt) } + clips.sent.map { ($0.id, $0.createdAt) }
        let ids = Set(dated.map(\.0))
        if texts.keys.contains(where: { !ids.contains($0) }) {
            texts = texts.filter { ids.contains($0.key) }
            save()
        }
        queue = dated.sorted { $0.1 > $1.1 }
            .map(\.0)
            .filter { texts[$0] == nil && !failed.contains($0) && $0 != transcribingClipID }
        guard transcribingClipID == nil else { return }
        Task { await drain() }
    }

    func removeAll() {
        queue = []
        texts = [:]
        save()
    }

    private func drain() async {
        while !queue.isEmpty {
            let clipID = queue.removeFirst()
            transcribingClipID = clipID
            if let text = await transcribe(clipID) {
                texts[clipID] = text
                save()
            } else {
                failed.insert(clipID)
            }
        }
        transcribingClipID = nil
    }

    private func transcribe(_ clipID: String) async -> String? {
        guard let data = try? await AppModel.shared.api?.audio(clipID: clipID) else { return nil }
        let file = FileManager.default.temporaryDirectory.appending(path: "\(clipID).m4a")
        defer { try? FileManager.default.removeItem(at: file) }
        do {
            try data.write(to: file)
            return try await Self.transcribe(file)
        } catch {
            return nil
        }
    }

    // SpeechTranscriber where the hardware and language have it, otherwise
    // DictationTranscriber.
    private nonisolated static func transcribe(_ file: URL) async throws -> String {
        if SpeechTranscriber.isAvailable, let locale = await SpeechTranscriber.supportedLocale(equivalentTo: .current) {
            let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
            return try await analyze(file, with: transcriber) {
                try await transcriber.results.reduce(into: []) { $0.append(String($1.text.characters)) }
            }
        }
        guard let locale = await DictationTranscriber.supportedLocale(equivalentTo: .current) else {
            throw CocoaError(.featureUnsupported)
        }
        let transcriber = DictationTranscriber(locale: locale, preset: .longDictation)
        return try await analyze(file, with: transcriber) {
            try await transcriber.results.reduce(into: []) { $0.append(String($1.text.characters)) }
        }
    }

    private nonisolated static func analyze(_ file: URL, with module: any SpeechModule,
                                            results: @escaping @Sendable () async throws -> [String]) async throws -> String {
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
            try await request.downloadAndInstall()
        }
        let analyzer = SpeechAnalyzer(modules: [module])
        let collected = Task { try await results() }
        let audio = try AVAudioFile(forReading: file)
        if let end = try await analyzer.analyzeSequence(from: audio) {
            try await analyzer.finalizeAndFinish(through: end)
        } else {
            await analyzer.cancelAndFinishNow()
        }
        return try await collected.value
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func save() {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(texts).write(to: fileURL, options: .atomic)
    }
}
