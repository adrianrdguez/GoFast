//
//  SmallFlightWidget.swift
//  GoFastWidget
//
//  Small widget layout - compact design showing essential departure info.
//

import SwiftUI
import WidgetKit

struct SmallFlightWidget: View {
    var entry: FlightTimelineEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        if let flight = entry.flight {
            flightContent(flight: flight)
        } else {
            EmptyStateWidgetContainer {
                EmptyStateContent()
            }
        }
    }
    
    private func flightContent(flight: Flight) -> some View {
        WidgetContainer(alignment: .leading) {
            VStack(alignment: .leading, spacing: 4) {
                // Top: Flight number with icon
                HStack(spacing: 4) {
                    Image(systemName: "airplane")
                        .font(.caption)
                        .foregroundColor(urgencyColor)
                    
                    if let flightNumber = flight.flightNumber {
                        Text(flightNumber)
                            .font(.caption)
                            .fontWeight(.semibold)
                    } else {
                        Text("Flight")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Urgency indicator
                    Image(systemName: entry.urgencyLevel.iconName)
                        .font(.caption2)
                        .foregroundColor(urgencyColor)
                }
                
                Spacer()
                
                // Middle: Leave by time
                VStack(alignment: .leading, spacing: 2) {
                    Text("Leave by")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if let leaveTime = entry.leaveTime {
                        Text(formatTime(leaveTime))
                            .font(.title3)
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                
                Spacer()
                
                // Bottom: Countdown with transport icon
                HStack(spacing: 4) {
                    Image(systemName: "car.fill")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if let timeUntilLeave = entry.timeUntilLeave {
                        Text(formatCountdown(timeUntilLeave))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(urgencyColor)
                    } else {
                        Text("Departed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }
    
    private var urgencyColor: Color {
        switch entry.urgencyLevel {
        case .relaxed:
            return .green
        case .soon:
            return .orange
        case .urgent:
            return .red
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatCountdown(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        }
    }
}

// MARK: - Empty State Content

private struct EmptyStateContent: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "airplane")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("No upcoming flights")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Add a flight in GoFast")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding()
    }
}
