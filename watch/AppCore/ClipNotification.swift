// ClipNotification.swift
// AppCore
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import UserNotifications

enum ClipNotification {
    static let category = "clip"
    static let playAutomaticallyKey = "playAutomatically"
    private static let autoplayedKey = "autoplayedClipIDs"

    static func clipID(in content: UNNotificationContent) -> String? {
        guard let clipID = content.userInfo["clip_id"] as? String,
              content.userInfo["server_id"] as? String == AccountStore.load()?.serverID else {
            return nil
        }
        return clipID
    }

    // True the first time it is called for a clip, so a notification reopened
    // from Notification Center does not play again on its own.
    static func claimAutoplay(of clipID: String) -> Bool {
        let defaults = UserDefaults.standard
        var played = defaults.stringArray(forKey: autoplayedKey) ?? []
        guard !played.contains(clipID) else { return false }
        played.append(clipID)
        defaults.set(Array(played.suffix(200)), forKey: autoplayedKey)
        return true
    }
}
