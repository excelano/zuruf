// NotificationService.swift
// ZurufNotificationService
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import UserNotifications

// Downloads the clip before the alert shows, so the long-look notification
// can play it the moment it appears.
final class NotificationService: UNNotificationServiceExtension {
    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var content: UNMutableNotificationContent?
    private var download: Task<Void, Never>?

    override func didReceive(_ request: UNNotificationRequest,
                             withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        guard let content = request.content.mutableCopy() as? UNMutableNotificationContent,
              let clipID = content.userInfo["clip_id"] as? String,
              let account = AccountStore.load(),
              content.userInfo["server_id"] as? String == account.serverID else {
            contentHandler(request.content)
            return
        }
        self.contentHandler = contentHandler
        self.content = content

        download = Task {
            if let data = try? await ZurufAPI(account: account).audio(clipID: clipID) {
                let file = FileManager.default.temporaryDirectory
                    .appendingPathComponent(clipID)
                    .appendingPathExtension("m4a")
                if (try? data.write(to: file)) != nil,
                   let attachment = try? UNNotificationAttachment(identifier: clipID, url: file) {
                    content.attachments = [attachment]
                }
            }
            finish()
        }
    }

    override func serviceExtensionTimeWillExpire() {
        download?.cancel()
        finish()
    }

    private func finish() {
        guard let content, let contentHandler else { return }
        self.contentHandler = nil
        contentHandler(content)
    }
}
