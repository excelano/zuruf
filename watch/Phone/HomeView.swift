// HomeView.swift
// Phone
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack(path: $model.talkPath) {
            List {
                if let groups = model.contacts?.groups, !groups.isEmpty {
                    Section("Groups") {
                        ForEach(groups) { group in
                            ContactRow(recipient: .group(id: group.id, name: group.name), systemImage: "person.2")
                        }
                    }
                }
                if let people = model.contacts?.users {
                    Section("People") {
                        ForEach(people) { person in
                            ContactRow(recipient: .person(id: person.id, name: person.displayName),
                                       systemImage: person.isBot ? "arrow.uturn.backward" : "person")
                        }
                    }
                }
                if let error = model.refreshError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Zuruf")
            .navigationDestination(for: Recipient.self) { recipient in
                ConversationView(recipient: recipient)
            }
            .toolbar {
                NavigationLink {
                    SettingsView()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
            .refreshable {
                await model.refresh()
            }
        }
    }
}

private struct ContactRow: View {
    let recipient: Recipient
    let systemImage: String
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationLink(value: recipient) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(recipient.name)
                    if let lastActivity = model.clips?.lastActivity(with: recipient) {
                        Text(lastActivity, format: .relative(presentation: .named))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if let unplayed = model.clips?.unplayedCount(from: recipient), unplayed > 0 {
                    Text("\(unplayed)")
                        .font(.footnote.bold().monospacedDigit())
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentColor, in: Capsule())
                }
            }
        }
    }
}
