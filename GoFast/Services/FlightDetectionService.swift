//
//  FlightDetectionService.swift
//  GoFast
//
//  Service responsible for scanning calendar events and detecting flights using
//  a 3-tier priority system: structured events (highest confidence), keyword matches,
//  and flight number regex patterns (fallback).
//

import Foundation
import EventKit

/// Errors that can occur during flight detection
enum FlightDetectionError: Error {
    case calendarAccessDenied
    case calendarAccessRestricted
    case noEventsFound
    case parsingError(String)
    case invalidFlightData
    
    var localizedDescription: String {
        switch self {
        case .calendarAccessDenied:
            return "Calendar access was denied. Please enable it in Settings."
        case .calendarAccessRestricted:
            return "Calendar access is restricted on this device."
        case .noEventsFound:
            return "No calendar events found in the specified date range."
        case .parsingError(let details):
            return "Failed to parse flight data: \(details)"
        case .invalidFlightData:
            return "Invalid flight data detected."
        }
    }
}

/// Service that scans calendar events and detects flights using multiple strategies.
/// Implements the 3-tier detection priority:
/// 1. Structured events: IATA codes + flight keywords (highest confidence)
/// 2. Keyword matches: Flight keywords only (medium confidence)
/// 3. Flight number regex: Pattern matching (lowest confidence, fallback)
class FlightDetectionService {
    
    // MARK: - Properties
    
    /// EventKit store for accessing calendar data
    private let eventStore: EKEventStore
    
    /// Date range for scanning (default: next 90 days)
    private let scanDaysAhead: Int
    
    /// Keywords that indicate flight-related events (multi-language support)
    private let flightKeywords: [String]
    
    /// Regex pattern for flight numbers (e.g., "AA123", "KL 456")
    private let flightNumberPattern: String
    
    // MARK: - Initialization
    
    /// Creates a new FlightDetectionService instance.
    /// - Parameters:
    ///   - eventStore: EventKit store (defaults to shared store)
    ///   - scanDaysAhead: Number of days to scan ahead (default: 90)
    init(eventStore: EKEventStore = EKEventStore(), scanDaysAhead: Int = 90) {
        self.eventStore = eventStore
        self.scanDaysAhead = scanDaysAhead
        
        // Multi-language flight keywords
        self.flightKeywords = [
            // English
            "flight", "departure", "airport", "terminal", "gate", "boarding",
            "travel", "trip", "airlines", "flying",
            // Spanish
            "vuelo", "salida", "aeropuerto", "terminal", "puerta", "embarque",
            "viaje", "aerolíneas", "avión",
            // French
            "vol", "départ", "aéroport", "aeroport",
            // German
            "flug", "flughafen", "abflug",
            // Italian
            "volo", "aeroporto", "partenza",
            // Thai (romanized)
            "bin", "fly", "flight"
        ]
        
        // Flight number pattern: 2 letters + optional space + 2-4 digits
        // Examples: AA123, KL 456, BA789, SQ12
        self.flightNumberPattern = "[A-Z]{2}\\s?\\d{2,4}"
    }
    
    // MARK: - Public API
    
    /// Requests calendar access permission from the user.
    /// - Returns: Boolean indicating if access was granted
    /// - Throws: Error if permission request fails
    func requestCalendarAccess() async throws -> Bool {
        // iOS 17+ uses new API
        if #available(iOS 17.0, *) {
            return try await eventStore.requestFullAccessToEvents()
        } else {
            // iOS 16 and earlier
            return try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }
    
    /// Checks current calendar authorization status
    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }
    
    /// Scans calendar and detects flights using 3-tier priority system.
    /// - Returns: Array of detected flights sorted by departure time
    /// - Throws: FlightDetectionError if calendar access fails or other issues occur
    func detectFlights() async throws -> [Flight] {
        // Verify calendar access
        guard authorizationStatus == .fullAccess || authorizationStatus == .authorized else {
            throw FlightDetectionError.calendarAccessDenied
        }
        
        // Fetch calendar events
        let events = try await fetchCalendarEvents()
        guard !events.isEmpty else {
            throw FlightDetectionError.noEventsFound
        }
        
        // Detect flights using 3-tier priority system
        var detectedFlights: [Flight] = []
        var processedEventIds = Set<String>()
        
        for event in events {
            // Skip events we've already processed (avoid duplicates)
            guard !processedEventIds.contains(event.eventIdentifier) else { continue }
            
            // Tier 1: Structured events (highest confidence)
            if let flight = detectStructuredEvent(event) {
                detectedFlights.append(flight)
                processedEventIds.insert(event.eventIdentifier)
                continue
            }
            
            // Tier 2: Keyword matches (medium confidence)
            if let flight = detectKeywordEvent(event) {
                detectedFlights.append(flight)
                processedEventIds.insert(event.eventIdentifier)
                continue
            }
            
            // Tier 3: Flight number regex (lowest confidence)
            if let flight = detectFlightNumberEvent(event) {
                detectedFlights.append(flight)
                processedEventIds.insert(event.eventIdentifier)
                continue
            }
        }
        
        // Remove duplicates and sort
        let uniqueFlights = deduplicateFlights(detectedFlights)
        return uniqueFlights.sorted { $0.departureTime < $1.departureTime }
    }
    
    // MARK: - Tier 1: Structured Event Detection
    
    /// Detects flights from events containing both IATA codes and flight keywords.
    /// This is the highest confidence detection method.
    /// - Parameter event: Calendar event to analyze
    /// - Returns: Flight if detected, nil otherwise
    private func detectStructuredEvent(_ event: EKEvent) -> Flight? {
        let searchableText = "\(event.title ?? "") \(event.notes ?? "") \(event.location ?? "")"
        
        // Look for IATA airport codes (3 uppercase letters)
        guard let airportCode = extractIATACode(from: searchableText) else {
            return nil
        }
        
        // Verify the code is a known airport
        guard let airport = Airport.find(byIATACode: airportCode) else {
            return nil
        }
        
        // Check for flight keywords
        guard containsFlightKeywords(searchableText) else {
            return nil
        }
        
        // Extract flight number if available
        let flightNumber = extractFlightNumber(from: searchableText)
        
        // Extract terminal/gate if available
        let terminal = extractTerminal(from: searchableText)
        let gate = extractGate(from: searchableText)
        
        return Flight(
            flightNumber: flightNumber,
            airline: extractAirline(from: flightNumber),
            departureAirport: airport,
            arrivalAirport: nil, // Will be extracted if available in future
            departureTime: event.startDate,
            arrivalTime: event.endDate,
            detectionSource: .structuredEvent,
            terminal: terminal,
            gate: gate
        )
    }
    
    // MARK: - Tier 2: Keyword Detection
    
    /// Detects flights from events containing flight keywords but no IATA codes.
    /// Medium confidence - may have false positives.
    /// - Parameter event: Calendar event to analyze
    /// - Returns: Flight if detected with reasonable confidence, nil otherwise
    private func detectKeywordEvent(_ event: EKEvent) -> Flight? {
        let searchableText = "\(event.title ?? "") \(event.notes ?? "") \(event.location ?? "")"
        
        // Must contain flight keywords
        guard containsFlightKeywords(searchableText) else {
            return nil
        }
        
        // Try to extract airport from location field specifically
        if let location = event.location,
           let airportCode = extractIATACode(from: location),
           let airport = Airport.find(byIATACode: airportCode) {
            
            let flightNumber = extractFlightNumber(from: searchableText)
            
            return Flight(
                flightNumber: flightNumber,
                airline: extractAirline(from: flightNumber),
                departureAirport: airport,
                arrivalAirport: nil,
                departureTime: event.startDate,
                arrivalTime: event.endDate,
                detectionSource: .keywordMatch,
                terminal: extractTerminal(from: searchableText),
                gate: extractGate(from: searchableText)
            )
        }
        
        // If we have strong keyword indicators but no airport, we could:
        // 1. Skip it (conservative approach)
        // 2. Try to infer from context (future enhancement)
        // For MVP, we skip events without clear airport identification
        return nil
    }
    
    // MARK: - Tier 3: Flight Number Regex Detection
    
    /// Detects flights from events matching flight number regex patterns.
    /// Lowest confidence - used only as fallback.
    /// - Parameter event: Calendar event to analyze
    /// - Returns: Flight if pattern matches and airport can be inferred, nil otherwise
    private func detectFlightNumberEvent(_ event: EKEvent) -> Flight? {
        let searchableText = "\(event.title ?? "") \(event.notes ?? "") \(event.location ?? "")"
        
        // Must match flight number pattern
        guard let flightNumber = extractFlightNumber(from: searchableText) else {
            return nil
        }
        
        // Try to find airport code anywhere in the event
        if let airportCode = extractIATACode(from: searchableText),
           let airport = Airport.find(byIATACode: airportCode) {
            
            return Flight(
                flightNumber: flightNumber,
                airline: extractAirline(from: flightNumber),
                departureAirport: airport,
                arrivalAirport: nil,
                departureTime: event.startDate,
                arrivalTime: event.endDate,
                detectionSource: .flightNumberRegex,
                terminal: extractTerminal(from: searchableText),
                gate: extractGate(from: searchableText)
            )
        }
        
        return nil
    }
    
    // MARK: - Helper Methods
    
    /// Fetches calendar events within the scan window.
    /// - Returns: Array of calendar events
    private func fetchCalendarEvents() async throws -> [EKEvent] {
        let startDate = Date()
        guard let endDate = Calendar.current.date(byAdding: .day, value: scanDaysAhead, to: startDate) else {
            throw FlightDetectionError.parsingError("Could not calculate end date")
        }
        
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )
        
        return eventStore.events(matching: predicate)
    }
    
    /// Extracts IATA airport code from text (3 uppercase letters)
    private func extractIATACode(from text: String) -> String? {
        let pattern = "\\b[A-Z]{3}\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        
        for match in matches {
            if let matchRange = Range(match.range, in: text) {
                let code = String(text[matchRange])
                // Verify it's a known airport
                if Airport.find(byIATACode: code) != nil {
                    return code
                }
            }
        }
        
        return nil
    }
    
    /// Extracts flight number using regex pattern
    private func extractFlightNumber(from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: flightNumberPattern) else { return nil }
        
        let range = NSRange(text.startIndex..., in: text)
        if let match = regex.firstMatch(in: text, range: range),
           let matchRange = Range(match.range, in: text) {
            return String(text[matchRange]).uppercased()
        }
        
        return nil
    }
    
    /// Extracts airline code from flight number (first 2 letters)
    private func extractAirline(from flightNumber: String?) -> String? {
        guard let flightNumber = flightNumber, flightNumber.count >= 2 else { return nil }
        let index = flightNumber.index(flightNumber.startIndex, offsetBy: 2)
        return String(flightNumber[..<index])
    }
    
    /// Checks if text contains flight-related keywords
    private func containsFlightKeywords(_ text: String) -> Bool {
        let lowercaseText = text.lowercased()
        return flightKeywords.contains { keyword in
            lowercaseText.contains(keyword.lowercased())
        }
    }
    
    /// Extracts terminal information from text
    private func extractTerminal(from text: String) -> String? {
        let patterns = [
            "Terminal ([1-9][0-9]?)",
            "T([1-9][0-9]?)",
            "Terminal ([A-Z])"
        ]
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range),
               let matchRange = Range(match.range, in: text) {
                return String(text[matchRange])
            }
        }
        
        return nil
    }
    
    /// Extracts gate information from text
    private func extractGate(from text: String) -> String? {
        let patterns = [
            "Gate ([A-Z][0-9]{1,3})",
            "Gate ([0-9]{1,3})",
            "G([0-9]{1,3})"
        ]
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range),
               let matchRange = Range(match.range, in: text) {
                return String(text[matchRange])
            }
        }
        
        return nil
    }
    
    /// Removes duplicate flights based on flight number + departure time
    private func deduplicateFlights(_ flights: [Flight]) -> [Flight] {
        var uniqueFlights: [String: Flight] = [:]
        
        for flight in flights {
            let key = flight.deduplicationKey
            
            // Keep the flight with higher confidence if duplicate found
            if let existing = uniqueFlights[key] {
                if flight.detectionSource.confidence > existing.detectionSource.confidence {
                    uniqueFlights[key] = flight
                }
            } else {
                uniqueFlights[key] = flight
            }
        }
        
        return Array(uniqueFlights.values)
    }
}

// MARK: - Detection Result

/// Result of a flight detection operation
struct FlightDetectionResult {
    let flights: [Flight]
    let scanDateRange: ClosedRange<Date>
    let eventsScanned: Int
    let detectionBreakdown: [DetectionSource: Int]
    
    /// Most imminent upcoming flight (the one user should leave for next)
    var mostImminentFlight: Flight? {
        flights.mostImminent
    }
    
    /// Total number of flights detected
    var totalDetected: Int {
        flights.count
    }
}
