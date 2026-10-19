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
            UNNotificationCategory(identifier: ClipNotification.category, actions: [], intentIdentifiers: [])
        ])
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

    // Tapping a clip notification opens the app and plays it.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let content = response.notification.request.content
        guard let clipID = ClipNotification.clipID(in: content) else { return }
        await MainActor.run {
            ClipPlayer.shared.play(clipID: clipID, attachment: content.attachments.first?.url, category: .playback)
        }
    }
}
