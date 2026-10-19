// AppModel.swift
// Zuruf
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import UserNotifications
import WatchKit
import WidgetKit

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    #if DEBUG
    static let apnsEnvironment = "sandbox"
    #else
    static let apnsEnvironment = "production"
    #endif

    @Published private(set) var account = DemoMode.isActive ? DemoMode.account : AccountStore.load()
    @Published private(set) var contacts: Contacts? = DemoMode.isActive ? DemoMode.contacts : nil
    @Published private(set) var clips: ClipList? = DemoMode.isActive ? DemoMode.clips : nil
    @Published private(set) var refreshError: String?
    @Published var talkPath: [Recipient] = DemoMode.has("--demo-talk")
        ? [.group(id: DemoMode.crew.id, name: DemoMode.crew.name)] : []
    @Published var showInbox = DemoMode.has("--demo-inbox")
    let outbox = Outbox()

    private var apnsToken: String?

    var api: ZurufAPI? {
        account.map(ZurufAPI.init)
    }

    var unplayedCount: Int {
        clips?.received.filter { $0.playedAt == nil }.count ?? 0
    }

    func join(server: String, code: String, displayName: String) async throws {
        let url = try ZurufAPI.serverURL(from: server)
        let account = try await ZurufAPI.redeem(server: url, code: code, displayName: displayName)
        try AccountStore.save(account)
        self.account = account
        await registerDevice()
        await refresh()
    }

    // Deletes the account on the server, then forgets it here. An account the
    // server no longer knows is already gone, so a 401 still signs out.
    func deleteAccount() async throws {
        do {
            try await api?.deleteAccount()
        } catch APIError.status(401, _) {
        }
        signOut()
    }

    private func signOut() {
        AccountStore.delete()
        LastRecipient.clear()
        WidgetCenter.shared.reloadTimelines(ofKind: "Talk")
        outbox.removeAll()
        account = nil
        contacts = nil
        clips = nil
    }

    func requestNotifications() async {
        guard !DemoMode.isActive else { return }
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        WKApplication.shared().registerForRemoteNotifications()
    }

    func apnsTokenReceived(_ token: String) async {
        apnsToken = token
        await registerDevice()
    }

    func refresh() async {
        guard let api, !DemoMode.isActive else { return }
        do {
            async let fetchedContacts = api.contacts()
            async let fetchedClips = api.clips()
            self.contacts = try await fetchedContacts
            self.clips = try await fetchedClips
            refreshError = nil
        } catch {
            refreshError = error.localizedDescription
        }
    }

    func send(_ file: URL, to recipient: Recipient) {
        outbox.enqueue(file, to: recipient)
        if LastRecipient.load() != recipient {
            LastRecipient.save(recipient)
            WidgetCenter.shared.reloadTimelines(ofKind: "Talk")
        }
    }

    func talk(to recipient: Recipient) {
        talkPath = [recipient]
    }

    func markPlayed(_ clipID: String) async {
        try? await api?.markPlayed(clipID: clipID)
        await refresh()
    }

    func recipientName(of clip: SentClip) -> String {
        if let toGroup = clip.toGroup {
            return contacts?.name(ofGroup: toGroup) ?? "Group"
        }
        return clip.toUser.flatMap { contacts?.name(ofUser: $0) } ?? "Someone"
    }

    private func registerDevice() async {
        guard let api, let apnsToken else { return }
        try? await api.registerDevice(apnsToken: apnsToken, environment: Self.apnsEnvironment)
    }
}
