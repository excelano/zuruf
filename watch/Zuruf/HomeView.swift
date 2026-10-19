// HomeView.swift
// Zuruf
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var outbox = AppModel.shared.outbox

    var body: some View {
        NavigationStack(path: $model.talkPath) {
            List {
                Section {
                    Button {
                        model.showInbox = true
                    } label: {
                        HStack {
                            Label("Inbox", systemImage: "tray")
                            Spacer()
                            if model.unplayedCount > 0 {
                                Text("\(model.unplayedCount)")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    if !outbox.items.isEmpty {
                        Label("\(outbox.items.count) waiting to send", systemImage: "arrow.up.circle")
                            .foregroundStyle(.secondary)
                    }
                }
                if let groups = model.contacts?.groups, !groups.isEmpty {
                    Section("Groups") {
                        ForEach(groups) { group in
                            NavigationLink(value: Recipient.group(id: group.id, name: group.name)) {
                                Label(group.name, systemImage: "person.2")
                            }
                        }
                    }
                }
                if let people = model.contacts?.users {
                    Section("People") {
                        ForEach(people) { person in
                            NavigationLink(value: Recipient.person(id: person.id, name: person.displayName)) {
                                Label(person.displayName, systemImage: person.isBot ? "arrow.uturn.backward" : "person")
                            }
                        }
                    }
                }
                if let error = model.refreshError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                NavigationLink {
                    SettingsView()
                } label: {
                    Label("Settings", systemImage: "gear")
                }
            }
            .navigationTitle("Zuruf")
            .navigationDestination(for: Recipient.self) { recipient in
                TalkView(recipient: recipient)
            }
            .navigationDestination(isPresented: $model.showInbox) {
                InboxView()
            }
            .refreshable {
                await model.refresh()
            }
        }
    }
}
