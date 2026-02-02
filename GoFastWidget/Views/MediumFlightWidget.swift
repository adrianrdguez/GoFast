//
//  MediumFlightWidget.swift
//  GoFastWidget
//
//  Medium widget layout - expanded design with route and transport details.
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
                // Top section: Flight info and leave time
                HStack(alignment: .top, spacing: 12) {
                    // Left: Flight details
                    VStack(alignment: .leading, spacing: 4) {
                        // Flight number with icon
                        HStack(spacing: 4) {
                            Image(systemName: "airplane")
                                .font(.caption)
                                .foregroundColor(urgencyColor)
                            
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
                        
                        // Route
                        Text("\(flight.departureAirport.id) → \(flight.arrivalAirport?.id ?? "?")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        // Departure time
                        Text("Depart: \(formatTime(flight.departureTime))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Right: Leave time countdown
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Leave by")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let leaveTime = entry.leaveTime {
                            Text(formatTime(leaveTime))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(urgencyColor)
                            
                            if let timeUntilLeave = entry.timeUntilLeave, timeUntilLeave > 0 {
                                Text(formatCountdown(timeUntilLeave))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(urgencyColor.opacity(0.8))
                            }
                        } else {
                            Text("--:--")
                                .font(.title2)
                                .foregroundColor(.secondary)
                        }
                        
                        // Urgency icon
                        Image(systemName: entry.urgencyLevel.iconName)
                            .font(.caption)
                            .foregroundColor(urgencyColor)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                Divider()
                    .padding(.horizontal, 16)
                
                // Bottom section: Transport info
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
                    
                    // ETA
                    if let timeUntilLeave = entry.timeUntilLeave {
                        Text("ETA: \(formatDuration(max(0, timeUntilLeave)))")
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
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
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
            return "(\(minutes) min)"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "(\(hours)h \(remainingMinutes)m)"
        }
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            return "\(hours)h \(minutes % 60)m"
        }
    }
}

// MARK: - Empty State Content (same as SmallFlightWidget)

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
