//
//  MediumFlightWidget.swift
//  GoFastWidget
//
//  Medium widget layout - expanded design with route and transport details.
//  Displays different information based on FlightState:
//  - Upcoming: Full context (route, departure date/time), no urgency
//  - Prepare: Context + countdown to departure, no transport
//  - Go Mode: Full display including "Leave by", ETA, transport section
//

import SwiftUI
import WidgetKit

struct MediumFlightWidget: View {
    var entry: FlightTimelineEntry
    
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
        WidgetContainer(alignment: .top) {
            VStack(spacing: 0) {
                // Top section: Flight info - varies by state
                topSection(flight: flight)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                
                // Divider (only show transport section exists)
                if entry.flightState == .goMode {
                    Divider()
                        .padding(.horizontal, 16)
                    
                    // Bottom section: Transport info (Go Mode only)
                    transportSection()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
            }
        }
    }
    
    // MARK: - Top Section (State-Based)
    
    private func topSection(flight: Flight) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Left: Flight details
            VStack(alignment: .leading, spacing: 4) {
                // Flight number with icon
                HStack(spacing: 4) {
                    Image(systemName: "airplane")
                        .font(.caption)
                        .foregroundColor(airplaneColor)
                    
                    if let flightNumber = flight.flightNumber {
                        Text(flightNumber)
                            .font(.headline)
                            .fontWeight(.bold)
                    } else {
                        Text("Flight")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Route (never shows "?")
                Text(routeDisplay(for: flight))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Departure time
                Text("Depart: \(formatTime(flight.departureTime))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Right: State-specific display
            rightSection()
        }
    }
    
    private func rightSection() -> some View {
        VStack(alignment: .trailing, spacing: 4) {
            // State label
            Text(entry.flightState.label)
                .font(.caption)
                .foregroundColor(stateLabelColor)
            
            switch entry.flightState {
            case .upcoming:
                // Show departure date
                if let timeUntilDeparture = entry.timeUntilDeparture {
                    Text(formatDateShort(Date().addingTimeInterval(timeUntilDeparture)))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                
            case .prepare:
                // Show countdown to departure
                if let timeUntilDeparture = entry.timeUntilDeparture {
                    Text(formatCountdown(timeUntilDeparture))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("until departure")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
            case .goMode:
                // Show leave by time with urgency
                Text("Leave by")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let leaveTime = entry.leaveTime {
                    Text(formatTime(leaveTime))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(urgencyColor)
                    
                    if let timeUntilLeave = entry.timeUntilLeave {
                        if timeUntilLeave > 0 {
                            Text(formatCountdown(timeUntilLeave))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(urgencyColor.opacity(0.8))
                        } else {
                            Text("Depart now!")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.red)
                        }
                    }
                } else {
                    Text("--:--")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                
                // Urgency icon (Go Mode only)
                Image(systemName: entry.urgencyLevel.iconName)
                    .font(.caption)
                    .foregroundColor(urgencyColor)
            }
        }
    }
    
    // MARK: - Transport Section (Go Mode Only)
    
    private func transportSection() -> some View {
        HStack {
            // Transport icon and name
            HStack(spacing: 6) {
                Image(systemName: "car.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Car")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // ETA (only in Go Mode)
            if let timeUntilLeave = entry.timeUntilLeave {
                let etaMinutes = Int(max(0, timeUntilLeave) / 60)
                Text("ETA: \(etaMinutes) min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Go button (opens app)
            HStack(spacing: 2) {
                Text("Open")
                    .font(.caption)
                    .fontWeight(.medium)
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
            }
            .foregroundColor(.blue)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(6)
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
    
    private func formatDateShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatCountdown(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 0 {
            return "Departed"
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
