// TalkWidget.swift
// ZurufWidgets
// Author: David M. Anderson
// Built with AI assistance (Claude, Anthropic)

import SwiftUI
import WidgetKit

@main
struct ZurufWidgets: WidgetBundle {
    var body: some Widget {
        TalkWidget()
    }
}

struct TalkEntry: TimelineEntry {
    let date: Date
    let recipient: Recipient?
}

// The app reloads this timeline whenever it sends a clip to someone new.
struct TalkProvider: TimelineProvider {
    func placeholder(in context: Context) -> TalkEntry {
        TalkEntry(date: .now, recipient: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TalkEntry) -> Void) {
        completion(TalkEntry(date: .now, recipient: LastRecipient.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TalkEntry>) -> Void) {
        completion(Timeline(entries: [TalkEntry(date: .now, recipient: LastRecipient.load())], policy: .never))
    }
}

struct TalkWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Talk", provider: TalkProvider()) { entry in
            TalkWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Talk")
        .description("Opens Zuruf ready to talk to whoever you last talked to.")
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
