//
//  GoFastWidget.swift
//  GoFastWidget
//
//  Main widget configuration and entry point.
//

import WidgetKit
import SwiftUI

/// Main widget configuration
@main
struct GoFastWidget: Widget {
    let kind: String = "FlightWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: kind,
            provider: FlightTimelineProvider()
        ) { entry in
            FlightWidgetEntryView(entry: entry)
                .widgetURL(widgetURL(for: entry))
        }
        .configurationDisplayName("GoFast Flight")
        .description("Shows when to leave for your next flight")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
    
    /// Generates deep link URL for widget tap
    private func widgetURL(for entry: FlightTimelineEntry) -> URL? {
        guard let flight = entry.flight else {
            return URL(string: "gofast://")
        }
        return URL(string: "gofast://flight/\(flight.id)")
    }
}

/// Main widget entry view that switches between small and medium layouts
struct FlightWidgetEntryView: View {
    var entry: FlightTimelineEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            SmallFlightWidget(entry: entry)
        case .systemMedium:
            MediumFlightWidget(entry: entry)
        default:
            SmallFlightWidget(entry: entry)
        }
    }
}
