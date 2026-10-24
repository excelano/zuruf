// HomeView.swift
// Phone
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            List {
                if let contacts = model.contacts {
                    if !contacts.groups.isEmpty {
                        Section("Groups") {
                            ForEach(contacts.groups) { group in
                                Text(group.name)
                            }
                        }
                    }
                    Section("People") {
                        ForEach(contacts.users) { person in
                            Text(person.displayName)
                        }
                    }
                } else if let error = model.refreshError {
                    Text(error)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Zuruf")
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
