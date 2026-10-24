// AppModel.swift
// AppCore
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import UserNotifications
import WidgetKit
#if os(watchOS)
import WatchKit
#else
import UIKit
#endif

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    #if DEBUG
    static let apnsEnvironment = "sandbox"
    #else
    static let apnsEnvironment = "production"
    #endif

    #if os(watchOS)
    static let platform = "watchos"
    #else
    static let platform = "ios"
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
        try await signIn(account)
        AccountLink.shared.share(account)
    }

    // Signs in with the account the paired watch or phone passed over, as a
    // device of its own. One already signed in keeps its account.
    func adopt(_ shared: Account) async {
        guard account == nil, !DemoMode.isActive,
              let account = try? await ZurufAPI(account: shared).linkDevice() else { return }
        try? await signIn(account)
    }

    // The paired watch or phone deleted this account, so it is gone here too.
    func signedOutElsewhere(_ userID: String) {
        if account?.userID == userID {
            signOut()
        }
    }

    private func signIn(_ account: Account) async throws {
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
        if let account {
            AccountLink.shared.shareSignOut(of: account.userID)
        }
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
        #if os(watchOS)
        WKApplication.shared().registerForRemoteNotifications()
        #else
        UIApplication.shared.registerForRemoteNotifications()
        #endif
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

    // Clears the unplayed dot at once; the refresh restores it if the server refused.
    func markPlayed(_ clipID: String) async {
        if let index = clips?.received.firstIndex(where: { $0.id == clipID && $0.playedAt == nil }) {
            clips?.received[index].playedAt = Date()
        }
        try? await api?.markPlayed(clipID: clipID)
        await refresh()
    }

    func deleteClip(_ clipID: String) async {
        clips?.received.removeAll { $0.id == clipID }
        try? await api?.deleteClip(clipID: clipID)
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
        try? await api.registerDevice(apnsToken: apnsToken, environment: Self.apnsEnvironment, platform: Self.platform)
    }
}
