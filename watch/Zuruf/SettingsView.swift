// SettingsView.swift
// Zuruf
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage(ClipNotification.playAutomaticallyKey) private var playAutomatically = true
    @State private var confirmLeave = false

    var body: some View {
        List {
            Section {
                Toggle("Play automatically", isOn: $playAutomatically)
            } footer: {
                Text("Plays new messages as they arrive. On silent, tap Play instead.")
            }
            if let account = model.account {
                Section {
                    LabeledContent("Name", value: account.displayName)
                    LabeledContent("Server", value: account.serverURL.host() ?? "")
                }
            }
            Button("Leave server", role: .destructive) {
                confirmLeave = true
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Leave this server?", isPresented: $confirmLeave) {
            Button("Leave", role: .destructive) { model.leave() }
        } message: {
            Text("You will need a new invite to join again.")
        }
    }
}
