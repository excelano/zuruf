// ZurufPhoneApp.swift
// Phone
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI
import UserNotifications

@main
struct ZurufPhoneApp: App {
    @UIApplicationDelegateAdaptor private var delegate: AppDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if model.account == nil {
                    OnboardingView()
                } else {
                    HomeView()
                }
            }
            .environmentObject(model)
            .onChange(of: model.clips) { _, clips in
                if let clips {
                    clipsChanged(clips)
                }
            }
            .onChange(of: model.account == nil) { _, signedOut in
                if signedOut {
                    Transcripts.shared.removeAll()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await model.refresh() }
            }
        }
    }
}

// Transcribes new clips and sets the badge to the unplayed count, whether the
// list changed in the app or from a background push.
@MainActor
private func clipsChanged(_ clips: ClipList) {
    Transcripts.shared.update(for: clips)
    UNUserNotificationCenter.current().setBadgeCount(clips.received.filter { $0.playedAt == nil }.count)
}

// A person with a watch is alerted there, and this phone gets a background
// push; a person with only this phone gets the alert here.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        AccountLink.shared.activate()
        Task { @MainActor in
            AppModel.shared.outbox.send()
            await AppModel.shared.requestNotifications()
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in await AppModel.shared.apnsTokenReceived(token) }
    }

    // A background push: fetch the new clip and transcribe it before iOS
    // suspends the app again.
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        await AppModel.shared.refresh()
        guard let clips = AppModel.shared.clips else { return .failed }
        clipsChanged(clips)
        await Transcripts.shared.finish()
        return .newData
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        Task { @MainActor in await AppModel.shared.refresh() }
        return [.banner, .list, .sound]
    }

    // Tapping a clip's alert opens its conversation, where it can be played
    // and answered.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard let clipID = ClipNotification.clipID(in: response.notification.request.content) else { return }
        await AppModel.shared.reply(toClip: clipID)
    }
}
