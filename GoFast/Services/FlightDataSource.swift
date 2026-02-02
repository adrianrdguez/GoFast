//
//  FlightDataSource.swift
//  GoFast
//
//  Protocol abstraction for flight data sources.
//  Enables switching between Google Calendar (primary) and Apple Calendar (fallback).
//

import Foundation
import EventKit

// MARK: - Protocol

/// Abstraction for flight data sources
protocol FlightDataSource {
    /// Fetches upcoming flights from the data source
    func fetchFlights() async throws -> [Flight]
    
    /// Human-readable source name
    var sourceName: String { get }
    
    /// Whether this source requires authentication
    var requiresAuth: Bool { get }
    
    /// Whether the source is currently available/connected
    var isAvailable: Bool { get }
    
    /// When the source was last synced
    var lastSyncDate: Date? { get }
}

// MARK: - Google Calendar Implementation

class GoogleCalendarDataSource: FlightDataSource {
    let sourceName = "Google Calendar"
    let requiresAuth = true
    
    var isAvailable: Bool {
        GoogleCalendarAuthService.shared.isSignedIn
    }
    
    var lastSyncDate: Date? {
        UserDefaults.standard.object(forKey: "com.gofast.google.lastSync") as? Date
    }
    
    private let apiService = GoogleCalendarAPIService.shared
    
    func fetchFlights() async throws -> [Flight] {
        // Google Calendar integration not yet implemented
        // Return empty array for now
        return []
    }
    
    private func parseFlight(from event: GoogleCalendarEvent) -> Flight? {
        // Not implemented - Google Calendar integration pending
        return nil
    }
    
    private func extractFlightNumber(from text: String) -> String? {
        let pattern = "([A-Z]{2,3})\\s*(\\d{2,4}[A-Z]?)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        return (text as NSString).substring(with: match.range)
    }
    
    private func extractAirports(from text: String) -> (departure: String, arrival: String?) {
        // Extract all 3-letter codes that match known airports
        let pattern = "\\b([A-Z]{3})\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return ("Unknown", nil)
        }
        
        let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        let codes = matches.compactMap { match -> String? in
            let code = (text as NSString).substring(with: match.range)
            return Airport.find(byIATACode: code) != nil ? code : nil
        }
        
        guard let departure = codes.first else {
            return ("Unknown", nil)
        }
        
        let arrival = codes.count > 1 ? codes[1] : nil
        return (departure, arrival)
    }
}

// MARK: - Apple Calendar Implementation

class AppleCalendarDataSource: FlightDataSource {
    let sourceName = "Apple Calendar"
    let requiresAuth = false
    
    var isAvailable: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        return status == .fullAccess || status == .authorized
    }
    
    var lastSyncDate: Date? {
        UserDefaults.standard.object(forKey: "com.gofast.apple.lastSync") as? Date
    }
    
    private let eventStore = EKEventStore()
    
    func fetchFlights() async throws -> [Flight] {
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .fullAccess || status == .authorized else {
            throw FlightDetectionError.calendarAccessDenied
        }
        
        // Fetch events from next 90 days
        let startDate = Date()
        let endDate = Date().addingTimeInterval(90 * 24 * 60 * 60)
        
        let calendars = eventStore.calendars(for: .event)
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        let events = eventStore.events(matching: predicate)
        
        // Parse flights with lower confidence
        let flights = events.compactMap { event -> Flight? in
            self.parseFlight(from: event)
        }
        
        UserDefaults.standard.set(Date(), forKey: "com.gofast.apple.lastSync")
        
        return flights
    }
    
    private func parseFlight(from event: EKEvent) -> Flight? {
        let title = event.title ?? ""
        let notes = event.notes ?? ""
        let location = event.location ?? ""
        let combinedText = "\(title) \(notes) \(location)"
        
        // Extract flight number
        let flightNumber = extractFlightNumber(from: title)
        
        // Extract airports
        let (departureIATA, arrivalIATA) = extractAirports(from: combinedText)
        
        guard let departureAirport = Airport.find(byIATACode: departureIATA) else {
            return nil
        }
        
        let arrivalAirport = arrivalIATA.flatMap { Airport.find(byIATACode: $0) }
        
        return Flight(
            id: UUID(),
            flightNumber: flightNumber,
            airline: nil,
            departureAirport: departureAirport,
            arrivalAirport: arrivalAirport,
            departureTime: event.startDate,
            arrivalTime: event.endDate,
            detectionSource: .structuredEvent,
            detectedAt: Date(),
            terminal: nil,
            gate: nil,
            seat: nil
        )
    }
    
    private func extractFlightNumber(from text: String) -> String? {
        let pattern = "([A-Z]{2,3})\\s*(\\d{2,4}[A-Z]?)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        return (text as NSString).substring(with: match.range)
    }
    
    private func extractAirports(from text: String) -> (departure: String, arrival: String?) {
        let pattern = "\\b([A-Z]{3})\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return ("Unknown", nil)
        }
        
        let matches = regex.matches(in: text, options: [], range: NSRange(text.startIndex..., in: text))
        let codes = matches.compactMap { match -> String? in
            let code = (text as NSString).substring(with: match.range)
            return Airport.find(byIATACode: code) != nil ? code : nil
        }
        
        guard let departure = codes.first else {
            return ("Unknown", nil)
        }
        
        let arrival = codes.count > 1 ? codes[1] : nil
        return (departure, arrival)
    }
}


