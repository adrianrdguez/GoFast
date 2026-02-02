//
//  SmallFlightWidget.swift
//  GoFastWidget
//
//  Small widget layout - compact design showing essential departure info.
//  Displays different information based on FlightState:
//  - Upcoming: Flight number, route, departure date
//  - Prepare: Flight number, countdown to departure
//  - Go Mode: Leave by time, countdown, urgency indicators
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
                // Top: Flight number with state label
                HStack(spacing: 4) {
                    Image(systemName: "airplane")
                        .font(.caption)
                        .foregroundColor(airplaneColor)
                    
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
                    
                    // State indicator (only in Go Mode)
                    if entry.flightState == .goMode {
                        Image(systemName: entry.urgencyLevel.iconName)
                            .font(.caption2)
                            .foregroundColor(urgencyColor)
                    }
                }
                
                // State label micro-copy
                Text(entry.flightState.label)
                    .font(.caption2)
                    .foregroundColor(stateLabelColor)
                
                Spacer()
                
                // Middle: Content based on flight state
                switch entry.flightState {
                case .upcoming:
                    upcomingContent(flight: flight)
                case .prepare:
                    prepareContent()
                case .goMode:
                    goModeContent()
                }
                
                Spacer()
                
                // Bottom: Route (always shown, never "?")
                HStack(spacing: 4) {
                    Text(routeDisplay(for: flight))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }
    
    // MARK: - State-Based Content
    
    private func upcomingContent(flight: Flight) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Departure")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(formatDateTime(flight.departureTime))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
    }
    
    private func prepareContent() -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let timeUntilDeparture = entry.timeUntilDeparture {
                Text(formatCountdownToDeparture(timeUntilDeparture))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("until departure")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func goModeContent() -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Leave by")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if let leaveTime = entry.leaveTime {
                Text(formatTime(leaveTime))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(urgencyColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text("--:--")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            if let timeUntilLeave = entry.timeUntilLeave {
                if timeUntilLeave > 0 {
                    Text(formatCountdown(timeUntilLeave))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(urgencyColor)
                } else {
                    Text("Depart now!")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var airplaneColor: Color {
        switch entry.flightState {
        case .upcoming, .prepare:
            return .secondary
        case .goMode:
            return urgencyColor
        }
    }
    
    private var stateLabelColor: Color {
        switch entry.flightState {
        case .upcoming:
            return .secondary
        case .prepare:
            return .blue.opacity(0.8)
        case .goMode:
            return urgencyColor
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
    
    private func routeDisplay(for flight: Flight) -> String {
        let departure = flight.departureAirport.id
        let arrival = flight.arrivalAirport?.id
            ?? flight.arrivalAirport?.city 
            ?? "Destination"
        return "\(departure) → \(arrival)"
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatCountdown(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 0 {
            return "Overdue"
        } else if minutes < 60 {
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
    
    private func formatCountdownToDeparture(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            } else if remainingMinutes < 10 {
                return "\(hours)h 0\(remainingMinutes)m"
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
