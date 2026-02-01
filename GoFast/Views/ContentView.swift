//
//  ContentView.swift
//  GoFast
//
//  Debug screen for testing flight detection from calendar.
//  Shows calendar permission handling, flight scanning, and detected flights list.
//

import SwiftUI
import EventKit
import Combine

struct ContentView: View {
    @StateObject private var viewModel = FlightDebugViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Status header
                statusHeader
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Permission section
                        permissionSection
                        
                        Divider()
                        
                        // Action buttons
                        actionButtonsSection
                        
                        Divider()
                        
                        // Flights list
                        flightsListSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Flight Detection Debug")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Status Header
    
    private var statusHeader: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            
            Text(viewModel.statusMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(UIColor.separator)),
            alignment: .bottom
        )
    }
    
    private var statusColor: Color {
        switch viewModel.calendarAccessStatus {
        case .fullAccess, .authorized:
            return .green
        case .denied, .restricted:
            return .red
        default:
            return .orange
        }
    }
    
    // MARK: - Permission Section
    
    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Calendar Access")
                .font(.headline)
            
            if viewModel.calendarAccessStatus == .notDetermined {
                Text("GoFast scans your calendar to automatically detect upcoming flights and calculate the ideal time to leave for the airport.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button("Grant Calendar Access") {
                    Task {
                        await viewModel.requestCalendarAccess()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else if viewModel.calendarAccessStatus == .denied || viewModel.calendarAccessStatus == .restricted {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text("Calendar access denied. Enable in Settings > Privacy & Security > Calendars.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Button("Check Permission Again") {
                    viewModel.checkCalendarStatus()
                }
                .buttonStyle(.bordered)
            } else {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Calendar access granted")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)
            
            HStack(spacing: 12) {
                Button {
                    Task {
                        await viewModel.scanCalendar()
                    }
                } label: {
                    Label("Scan Calendar", systemImage: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading || !(viewModel.calendarAccessStatus == .fullAccess || viewModel.calendarAccessStatus == .authorized))
                
                Button {
                    viewModel.addMockFlight()
                } label: {
                    Label("Add Mock", systemImage: "plus.circle")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoading)
                
                if !viewModel.flights.isEmpty {
                    Button {
                        viewModel.clearFlights()
                    } label: {
                        Label("Clear", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            if let error = viewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Flights List
    
    private var flightsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Detected Flights")
                    .font(.headline)
                
                Spacer()
                
                if !viewModel.flights.isEmpty {
                    Text("\(viewModel.flights.count) total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if viewModel.flights.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "airplane")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No flights detected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Scan your calendar or add a mock flight to test")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 150)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.flights) { flight in
                        FlightDebugCard(
                            flight: flight,
                            showDetails: viewModel.shouldShowDebugDetails(for: flight.id),
                            onToggleDetails: {
                                viewModel.toggleDebugDetails(for: flight.id)
                            }
                        )
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Flight Debug Card

struct FlightDebugCard: View {
    let flight: Flight
    let showDetails: Bool
    let onToggleDetails: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Main flight info
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    // Flight number or description
                    if let flightNumber = flight.flightNumber {
                        Text(flightNumber)
                            .font(.title3)
                            .fontWeight(.bold)
                    } else {
                        Text("Flight (no number)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary)
                    }
                    
                    // Route
                    Text("\(flight.departureAirport.id) → \(flight.arrivalAirport?.id ?? "?")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Detection confidence badge
                Text(flight.detectionSource.shortLabel)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(flight.detectionSource.confidenceColor.opacity(0.2))
                    .foregroundColor(flight.detectionSource.confidenceColor)
                    .cornerRadius(4)
            }
            
            Divider()
            
            // Flight details
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Label {
                        Text(formatDate(flight.departureTime))
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    .font(.subheadline)
                    
                    Label {
                        Text(formatTime(flight.departureTime))
                    } icon: {
                        Image(systemName: "clock")
                    }
                    .font(.subheadline)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if let terminal = flight.terminal {
                        Label {
                            Text(terminal)
                        } icon: {
                            Image(systemName: "building.2")
                        }
                        .font(.caption)
                    }
                    
                    if let gate = flight.gate {
                        Label {
                            Text(gate)
                        } icon: {
                            Image(systemName: "door.left.hand.open")
                        }
                        .font(.caption)
                    }
                }
            }
            
            // Debug details toggle
            Button(action: onToggleDetails) {
                HStack {
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                    Text(showDetails ? "Hide Debug Details" : "Show Debug Details")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundColor(.blue)
            }
            
            // Debug details (collapsible)
            if showDetails {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    Group {
                        DebugRow(label: "Flight ID", value: flight.id.uuidString.prefix(8).description + "...")
                        DebugRow(label: "Detection Method", value: flight.detectionSource.displayName)
                        DebugRow(label: "Confidence", value: "\(Int(flight.detectionSource.confidence * 100))%")
                        DebugRow(label: "Detected At", value: formatDateTime(flight.detectedAt))
                        DebugRow(label: "Airport", value: "\(flight.departureAirport.name) (\(flight.departureAirport.city))")
                        DebugRow(label: "Timezone", value: flight.departureAirport.timezoneIdentifier)
                        DebugRow(label: "International", value: flight.isInternational ? "Yes" : "No")
                        
                        if let airline = flight.airline {
                            DebugRow(label: "Airline", value: airline)
                        }
                        
                        if let arrival = flight.arrivalAirport {
                            DebugRow(label: "Destination", value: "\(arrival.id) - \(arrival.city)")
                        }
                        
                        DebugRow(label: "Time Until Departure", value: formatTimeInterval(flight.timeUntilDeparture))
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(UIColor.separator), lineWidth: 0.5)
        )
    }
    
    // MARK: - Formatting Helpers
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else if interval > 0 {
            return "< 1m"
        } else {
            return "Departed"
        }
    }
}

// MARK: - Debug Row

struct DebugRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

#Preview {
    ContentView()
}
