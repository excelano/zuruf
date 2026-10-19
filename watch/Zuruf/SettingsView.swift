// SettingsView.swift
// Zuruf
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @AppStorage(ClipNotification.playAutomaticallyKey) private var playAutomatically = true
    @State private var confirmDelete = false
    @State private var isDeleting = false
    @State private var deleteError: String?

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
            Section {
                Button(isDeleting ? "Deleting…" : "Delete account", role: .destructive) {
                    confirmDelete = true
                }
                .disabled(isDeleting)
            } footer: {
                if let deleteError {
                    Text(deleteError)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog("Delete your account?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) { delete() }
        } message: {
            Text("Your account and every message you sent or received are deleted from the server. You will need a new invite to join again.")
        }
    }

    private func delete() {
        isDeleting = true
        deleteError = nil
        Task {
            do {
                try await model.deleteAccount()
            } catch {
                deleteError = error.localizedDescription
            }
            isDeleting = false
        }
    }
}
