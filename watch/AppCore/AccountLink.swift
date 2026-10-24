// AccountLink.swift
// AppCore
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import WatchConnectivity

// Keeps a paired watch and phone on one account. Whichever joins passes the
// account to the other, which signs in as a device of its own; deleting the
// account on one signs the other out. The application context holds only the
// latest of these, and reaches the other app whenever it next runs.
final class AccountLink: NSObject, WCSessionDelegate {
    static let shared = AccountLink()

    private static let accountKey = "account"
    private static let signedOutKey = "signedOutUserID"

    func activate() {
        guard WCSession.isSupported(), !DemoMode.isActive else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func share(_ account: Account) {
        guard let data = try? JSONEncoder().encode(account) else { return }
        update([Self.accountKey: data])
    }

    func shareSignOut(of userID: String) {
        update([Self.signedOutKey: userID])
    }

    // Fails while the other app is not installed, which is fine: the account is
    // shared again on every launch.
    private func update(_ context: [String: Any]) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated else { return }
        try? WCSession.default.updateApplicationContext(context)
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        let context = session.receivedApplicationContext
        Task { @MainActor in
            await receive(context)
            if let account = AppModel.shared.account {
                share(account)
            }
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        Task { @MainActor in await receive(context) }
    }

    @MainActor
    private func receive(_ context: [String: Any]) async {
        if let data = context[Self.accountKey] as? Data,
           let account = try? JSONDecoder().decode(Account.self, from: data) {
            await AppModel.shared.adopt(account)
        } else if let userID = context[Self.signedOutKey] as? String {
            AppModel.shared.signedOutElsewhere(userID)
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}

    // Called when the phone switches to another paired watch.
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor in
            if let account = AppModel.shared.account {
                share(account)
            }
        }
    }
    #endif
}
