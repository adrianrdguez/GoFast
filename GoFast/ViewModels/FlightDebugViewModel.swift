//
//  FlightDebugViewModel.swift
//  GoFast
//
//  ViewModel for the debug screen that tests flight detection from calendar.
//  Handles permissions, scanning, and displaying results with debug information.
//

import Foundation
import EventKit
import SwiftUI
import Combine

/// ViewModel for the flight detection debug screen
@MainActor
class FlightDebugViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var flights: [Flight] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var statusMessage: String = "Ready to scan"
    @Published var calendarAccessStatus: EKAuthorizationStatus = .notDetermined
    @Published var showDebugDetails: [UUID: Bool] = [:] // Flight ID -> show details
    
    // MARK: - Services
    
    private let detectionService = FlightDetectionService()
    
    // MARK: - Initialization
    
    init() {
        checkCalendarStatus()
    }
    
    // MARK: - Calendar Permission
    
    /// Checks current calendar authorization status
    func checkCalendarStatus() {
        calendarAccessStatus = detectionService.authorizationStatus
        updateStatusMessage()
    }
    
    /// Requests calendar access permission
    func requestCalendarAccess() async {
        do {
            let granted = try await detectionService.requestCalendarAccess()
            calendarAccessStatus = granted ? .fullAccess : .denied
            updateStatusMessage()
        } catch {
            errorMessage = "Failed to request calendar access: \(error.localizedDescription)"
            calendarAccessStatus = .denied
        }
    }
    
    // MARK: - Flight Detection
    
    /// Scans calendar and detects flights
    func scanCalendar() async {
        guard calendarAccessStatus == .fullAccess || calendarAccessStatus == .authorized else {
            errorMessage = "Calendar access required. Please grant permission."
            return
        }
        
        isLoading = true
        errorMessage = nil
        statusMessage = "Scanning calendar..."
        
        do {
            let detectedFlights = try await detectionService.detectFlights()
            self.flights = detectedFlights
            
            if detectedFlights.isEmpty {
                statusMessage = "No flights detected. Try adding a mock flight."
            } else {
                statusMessage = "Found \(detectedFlights.count) flight(s)"
            }
        } catch FlightDetectionError.calendarAccessDenied {
            errorMessage = "Calendar access denied. Enable in Settings."
            statusMessage = "Permission denied"
        } catch FlightDetectionError.noEventsFound {
            errorMessage = "No calendar events found in the next 90 days."
            statusMessage = "No events found"
        } catch {
            errorMessage = "Scan failed: \(error.localizedDescription)"
            statusMessage = "Error occurred"
        }
        
        isLoading = false
    }
    
    // MARK: - Mock Data
    
    /// Adds a hardcoded mock flight for testing UI
    func addMockFlight() {
        guard let airport = Airport.find(byIATACode: "DMK") else {
            errorMessage = "Mock airport not found"
            return
        }
        
        let mockFlight = Flight(
            flightNumber: "AA123",
            airline: "American Airlines",
            departureAirport: airport,
            arrivalAirport: nil,
            departureTime: Date().addingTimeInterval(24 * 3600), // Tomorrow
            arrivalTime: nil,
            detectionSource: .manualEntry,
            terminal: "Terminal 1",
            gate: "Gate A12"
        )
        
        flights.append(mockFlight)
        statusMessage = "Added mock flight (\(flights.count) total)"
        errorMessage = nil
    }
    
    /// Clears all flights from the list
    func clearFlights() {
        flights.removeAll()
        showDebugDetails.removeAll()
        statusMessage = "Cleared all flights"
    }
    
    // MARK: - Debug Details
    
    /// Toggles debug details visibility for a flight
    func toggleDebugDetails(for flightId: UUID) {
        showDebugDetails[flightId] = !(showDebugDetails[flightId] ?? false)
    }
    
    /// Checks if debug details should be shown for a flight
    func shouldShowDebugDetails(for flightId: UUID) -> Bool {
        showDebugDetails[flightId] ?? false
    }
    
    // MARK: - Widget Integration
    
    /// Saves the first flight in the list to the widget via App Groups
    func saveFlightToWidget() {
        guard let flight = flights.first else {
            errorMessage = "No flights to save. Add a flight first."
            return
        }
        
        SharedDataService.shared.saveFlight(flight)
        statusMessage = "Flight saved to widget"
        errorMessage = nil
    }
    
    /// Clears all widget data
    func clearWidgetData() {
        SharedDataService.shared.clearFlight()
        statusMessage = "Widget data cleared"
    }
    
    /// Manually triggers a widget refresh
    func refreshWidget() {
        SharedDataService.shared.reloadWidget()
        statusMessage = "Widget refresh triggered"
    }
    
    /// Checks if App Groups is properly configured for widget
    var isWidgetConfigured: Bool {
        SharedDataService.shared.isConfigured
    }
    
    // MARK: - Helpers
    
    private func updateStatusMessage() {
        switch calendarAccessStatus {
        case .notDetermined:
            statusMessage = "Calendar permission needed"
        case .restricted:
            statusMessage = "Calendar access restricted"
        case .denied:
            statusMessage = "Calendar access denied"
        case .writeOnly:
            statusMessage = "Write-only access (insufficient)"
        case .authorized, .fullAccess:
            statusMessage = flights.isEmpty ? "Ready to scan" : "\(flights.count) flight(s) detected"
        @unknown default:
            statusMessage = "Unknown permission status"
        }
    }
}

// MARK: - DetectionSource Extension for UI

extension DetectionSource {
    /// Color for the detection confidence badge
    var confidenceColor: Color {
        switch self {
        case .structuredEvent:
            return .green
        case .keywordMatch:
            return .orange
        case .flightNumberRegex:
            return .yellow
        case .manualEntry:
            return .blue
        case .googleCalendar:
            return .purple
        case .appleCalendar:
            return .cyan
        }
    }
    
    /// Short label for UI
    var shortLabel: String {
        switch self {
        case .structuredEvent:
            return "Structured"
        case .keywordMatch:
            return "Keyword"
        case .flightNumberRegex:
            return "Regex"
        case .manualEntry:
            return "Manual"
        case .googleCalendar:
            return "Google"
        case .appleCalendar:
            return "Apple"
        }
    }
}
