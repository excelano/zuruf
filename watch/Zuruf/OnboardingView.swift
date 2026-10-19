// OnboardingView.swift
// Zuruf
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel
    @State private var server = Bundle.main.object(forInfoDictionaryKey: "ZurufDefaultServer") as? String ?? ""
    @State private var code = ""
    @State private var name = ""
    @State private var isJoining = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Server") {
                    TextField("Server", text: $server)
                        .textContentType(.URL)
                }
                Section("Invite") {
                    TextField("Invite code", text: $code)
                    TextField("Your name", text: $name)
                }
                if let error {
                    Text(error)
                        .foregroundStyle(.red)
                }
                Button(isJoining ? "Joining…" : "Join") {
                    join()
                }
                .disabled(isJoining || code.isEmpty || name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .navigationTitle("Zuruf")
        }
    }

    private func join() {
        isJoining = true
        error = nil
        Task {
            do {
                try await model.join(server: server, code: code, displayName: name)
            } catch {
                self.error = error.localizedDescription
            }
            isJoining = false
        }
    }
}
