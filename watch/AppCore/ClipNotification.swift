// ClipNotification.swift
// AppCore
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import Foundation
import UserNotifications

enum ClipNotification {
    static let category = "clip"
    static let playAutomaticallyKey = "playAutomatically"
    private static let playAutomaticallyChangedAtKey = "playAutomaticallyChangedAt"
    private static let autoplayedKey = "autoplayedClipIDs"

    static var playAutomatically: Bool {
        UserDefaults.standard.object(forKey: playAutomaticallyKey) as? Bool ?? true
    }

    // When the setting last changed, on whichever device changed it, so the
    // watch and phone keep the newer of their two values.
    static var playAutomaticallyChangedAt: Double {
        UserDefaults.standard.double(forKey: playAutomaticallyChangedAtKey)
    }

    static func setPlayAutomatically(_ isOn: Bool, changedAt: Double) {
        UserDefaults.standard.set(isOn, forKey: playAutomaticallyKey)
        UserDefaults.standard.set(changedAt, forKey: playAutomaticallyChangedAtKey)
    }

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
