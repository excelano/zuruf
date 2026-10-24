// ZurufApp.swift
// Zuruf
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI
import UserNotifications
import WatchKit

@main
struct ZurufApp: App {
    @WKApplicationDelegateAdaptor private var delegate: AppDelegate
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
            .onOpenURL { url in
                if let recipient = TalkLink.recipient(from: url) {
                    model.talk(to: recipient)
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await model.refresh() }
            }
        }
        WKNotificationScene(controller: NotificationController.self, category: ClipNotification.category)
    }
}

final class AppDelegate: NSObject, WKApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: ClipNotification.category,
                actions: [UNNotificationAction(identifier: ClipNotification.replyAction, title: "Reply", options: [.foreground])],
                intentIdentifiers: []
            )
        ])
        AccountLink.shared.activate()
        Task { @MainActor in
            AppModel.shared.outbox.send()
            await AppModel.shared.requestNotifications()
        }
    }

    func didRegisterForRemoteNotifications(withDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        Task { @MainActor in await AppModel.shared.apnsTokenReceived(token) }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        Task { @MainActor in await AppModel.shared.refresh() }
        return [.banner, .list, .sound]
    }

    // Reply opens the sender's talk screen; a tap on the notification only
    // opens the app.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == ClipNotification.replyAction,
              let clipID = ClipNotification.clipID(in: response.notification.request.content) else { return }
        await AppModel.shared.reply(toClip: clipID)
    }
}
