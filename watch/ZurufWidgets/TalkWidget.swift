// TalkWidget.swift
// ZurufWidgets
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import AppIntents
import SwiftUI
import WidgetKit

@main
struct ZurufWidgets: WidgetBundle {
    var body: some Widget {
        TalkWidget()
    }
}

struct SelectContactIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Contact"

    @Parameter(title: "Contact")
    var contact: ContactEntity?

    init() {}

    init(contact: ContactEntity?) {
        self.contact = contact
    }
}

struct TalkEntry: TimelineEntry {
    let date: Date
    let recipient: Recipient?
}

struct TalkProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TalkEntry {
        TalkEntry(date: .now, recipient: nil)
    }

    func snapshot(for configuration: SelectContactIntent, in context: Context) async -> TalkEntry {
        TalkEntry(date: .now, recipient: configuration.contact?.recipient)
    }

    func timeline(for configuration: SelectContactIntent, in context: Context) async -> Timeline<TalkEntry> {
        Timeline(entries: [TalkEntry(date: .now, recipient: configuration.contact?.recipient)], policy: .never)
    }

    // watchOS offers these in the face editor in place of a configuration screen.
    func recommendations() -> [AppIntentRecommendation<SelectContactIntent>] {
        [AppIntentRecommendation(intent: SelectContactIntent(contact: nil), description: "Zuruf")]
            + ContactsCache.load().map { recipient in
                AppIntentRecommendation(
                    intent: SelectContactIntent(contact: ContactEntity(recipient: recipient)),
                    description: "Talk to \(recipient.name)"
                )
            }
    }
}

struct TalkWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "Talk", intent: SelectContactIntent.self, provider: TalkProvider()) { entry in
            TalkWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Talk")
        .description("Opens Zuruf ready to talk.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

struct TalkWidgetView: View {
    let entry: TalkEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        content
            .widgetURL(entry.recipient.map(TalkLink.url(for:)))
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryCorner:
            Image(systemName: "mic.fill")
                .font(.title2)
                .widgetLabel(entry.recipient?.name ?? "Zuruf")
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Label("Zuruf", systemImage: "mic.fill")
                    .font(.headline)
                Text(entry.recipient.map { "Talk to \($0.name)" } ?? "Open to talk")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .accessoryInline:
            Label(entry.recipient.map { "Talk to \($0.name)" } ?? "Zuruf", systemImage: "mic.fill")
        default:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "mic.fill")
                    .font(.title3)
            }
        }
    }
}
