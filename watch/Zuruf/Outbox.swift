// Outbox.swift
// Zuruf
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation

// Recorded clips wait here, on disk, until the server accepts them.
@MainActor
final class Outbox: ObservableObject {
    struct Item: Codable, Identifiable {
        let id: UUID
        let recipient: Recipient
        var attempts: Int
    }

    @Published private(set) var items: [Item] = []
    private var isSending = false
    private let directory: URL
    private let indexURL: URL

    init() {
        directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("outbox", isDirectory: true)
        indexURL = directory.appendingPathComponent("outbox.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: indexURL) {
            items = (try? JSONDecoder().decode([Item].self, from: data)) ?? []
        }
    }

    func enqueue(_ file: URL, to recipient: Recipient) {
        let item = Item(id: UUID(), recipient: recipient, attempts: 0)
        guard (try? FileManager.default.moveItem(at: file, to: fileURL(item))) != nil else { return }
        items.append(item)
        save()
        send()
    }

    func send() {
        guard !isSending else { return }
        isSending = true
        Task {
            await drain()
            isSending = false
        }
    }

    func removeAll() {
        items.forEach { try? FileManager.default.removeItem(at: fileURL($0)) }
        items = []
        save()
    }

    private func drain() async {
        while let item = items.first {
            guard let api = AppModel.shared.api else { return }
            do {
                try await api.uploadClip(file: fileURL(item), to: item.recipient)
                remove(item)
                await AppModel.shared.refresh()
            } catch let error as APIError where error.isPermanent {
                remove(item)
            } catch {
                items[0].attempts += 1
                save()
                let delay = min(pow(2, Double(items[0].attempts)), 300)
                try? await Task.sleep(for: .seconds(delay))
            }
        }
    }

    private func remove(_ item: Item) {
        try? FileManager.default.removeItem(at: fileURL(item))
        items.removeAll { $0.id == item.id }
        save()
    }

    private func fileURL(_ item: Item) -> URL {
        directory.appendingPathComponent(item.id.uuidString).appendingPathExtension("m4a")
    }

    private func save() {
        try? JSONEncoder().encode(items).write(to: indexURL, options: .atomic)
    }
}
