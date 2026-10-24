// SettingsView.swift
// AppCore
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var link = AccountLink.shared
    @AppStorage(ClipNotification.playAutomaticallyKey) private var playAutomatically = true
    @State private var confirmDelete = false
    @State private var isDeleting = false
    @State private var deleteError: String?

    var body: some View {
        List {
            #if os(watchOS)
            Section {
                Toggle("Play automatically", isOn: playAutomaticallyBinding)
            } footer: {
                Text("Plays new messages as they arrive. On silent, tap Play instead.")
            }
            #else
            if link.hasWatch {
                Section {
                    Toggle("Play automatically on watch", isOn: playAutomaticallyBinding)
                } footer: {
                    Text("Your watch plays new messages as they arrive. On silent, it shows a Play button instead.")
                }
            }
            #endif
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

    // Reads through @AppStorage so a change from the paired device shows at
    // once; writes go through AccountLink, which passes them on.
    private var playAutomaticallyBinding: Binding<Bool> {
        Binding(get: { playAutomatically }, set: { link.setPlayAutomatically($0) })
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
