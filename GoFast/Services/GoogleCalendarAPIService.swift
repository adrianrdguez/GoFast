//
//  GoogleCalendarAPIService.swift
//  GoFast
//
//  Fetches and filters calendar events from Google Calendar API.
//  Uses local filtering with regex patterns for flight detection (not API-side filtering).
//

import Foundation

/// Fetches flight events from Google Calendar API with local filtering
class GoogleCalendarAPIService {
    static let shared = GoogleCalendarAPIService()
    
    private let baseURL = "https://www.googleapis.com/calendar/v3"
    private let authService = GoogleCalendarAuthService.shared
    
    // MARK: - Local Flight Detection Patterns
    
    /// Regex patterns for detecting flight-related events
    private struct FlightPatterns {
        // Flight numbers: AA123, BA 27, etc.
        static let flightNumber = try! NSRegularExpression(
            pattern: "\\b([A-Z]{2,3})\\s*(\\d{2,4}[A-Z]?)\\b",
            options: []
        )
        
        // IATA airport codes: JFK, LHR, etc.
        static let iataCode = try! NSRegularExpression(
            pattern: "\\b([A-Z]{3})\\b",
            options: []
        )
        
        // Flight-related keywords (multi-language support)
        static let keywords = [
            // English
            "flight", "fly", "flying", "departure", "arrival",
            // Spanish
            "vuelo", "volando",
            // French
            "vol", "décollage", "atterrissage",
            // German
            "flug", "abflug", "ankunft",
            // Italian
            "volo", "decollo", "arrivo",
            // Thai
            "เที่ยวบิน", "บิน"
        ]
        
        // Major airline IATA codes for quick matching
        static let airlineCodes = [
            "AA", "BA", "AF", "LH", "KL", "DL", "UA", "VS", "SQ", "CX",
            "EK", "QR", "LH", "AF", "BA", "AA", "UA", "DL", "JL", "NH"
        ]
    }
    
    // MARK: - Public API
    
    /// Fetches upcoming events from Google Calendar and filters for flights locally
    func fetchUpcomingEvents(daysAhead: Int = 90) async throws -> [GoogleCalendarEvent] {
        // Ensure we have a valid token
        let accessToken = try await authService.ensureValidAccessToken()
        
        // Build URL - fetch ALL events (no API-side filtering)
        let timeMin = ISO8601DateFormatter().string(from: Date())
        let timeMax = ISO8601DateFormatter().string(
            from: Date().addingTimeInterval(TimeInterval(daysAhead * 24 * 60 * 60))
        )
        
        var components = URLComponents(string: "\(baseURL)/calendars/primary/events")!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: timeMin),
            URLQueryItem(name: "timeMax", value: timeMax),
            URLQueryItem(name: "maxResults", value: "250"), // Get more events for filtering
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime")
            // Note: No "q" parameter - we filter locally
        ]
        
        guard let url = components.url else {
            throw CalendarAPIError.invalidURL
        }
        
        // Make request
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // Handle response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CalendarAPIError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            // Token expired, clear and throw
            authService.signOut()
            throw CalendarAPIError.unauthorized
        }
        
        guard httpResponse.statusCode == 200 else {
            throw CalendarAPIError.httpError(httpResponse.statusCode)
        }
        
        // Parse response
        let eventsResponse = try JSONDecoder().decode(CalendarEventsResponse.self, from: data)
        
        // Filter locally for flight events
        let flightEvents = eventsResponse.items.filter { isFlightEvent($0) }
        
        return flightEvents
    }
    
    // MARK: - Local Flight Detection
    
    /// Determines if a calendar event is flight-related using local filtering
    private func isFlightEvent(_ event: GoogleCalendarEvent) -> Bool {
        let combinedText = "\(event.summary) \(event.description ?? "") \(event.location ?? "")"
            .lowercased()
        
        // 1. Check for flight number pattern (strongest signal)
        let flightNumberRange = NSRange(combinedText.startIndex..., in: combinedText)
        if FlightPatterns.flightNumber.firstMatch(in: combinedText, options: [], range: flightNumberRange) != nil {
            return true
        }
        
        // 2. Check for flight keywords + IATA code
        let hasKeyword = FlightPatterns.keywords.contains { keyword in
            combinedText.contains(keyword.lowercased())
        }
        
        let hasIATA = FlightPatterns.iataCode.firstMatch(
            in: combinedText,
            options: [],
            range: flightNumberRange
        ) != nil
        
        if hasKeyword && hasIATA {
            return true
        }
        
        // 3. Check for airline code + flight-like context
        let hasAirlineCode = FlightPatterns.airlineCodes.contains { code in
            combinedText.contains(code.lowercased())
        }
        
        if hasAirlineCode && (hasKeyword || hasIATA) {
            return true
        }
        
        return false
    }
    
    /// Extracts confidence score for flight detection (0.0 - 1.0)
    func confidenceScore(for event: GoogleCalendarEvent) -> Double {
        let combinedText = "\(event.summary) \(event.description ?? "") \(event.location ?? "")"
        let textLowercased = combinedText.lowercased()
        var score = 0.0
        
        // Flight number pattern: +0.4 confidence
        let flightNumberRange = NSRange(combinedText.startIndex..., in: combinedText)
        if FlightPatterns.flightNumber.firstMatch(in: combinedText, options: [], range: flightNumberRange) != nil {
            score += 0.4
        }
        
        // Flight keywords: +0.2 each, max +0.3
        let keywordMatches = FlightPatterns.keywords.filter { keyword in
            textLowercased.contains(keyword.lowercased())
        }.count
        score += min(Double(keywordMatches) * 0.2, 0.3)
        
        // IATA codes (valid airports): +0.15 each, max +0.3
        let matches = FlightPatterns.iataCode.matches(in: combinedText, options: [], range: flightNumberRange)
        let validAirports = matches.compactMap { match -> String? in
            let code = (combinedText as NSString).substring(with: match.range)
            return Airport.find(byIATACode: code) != nil ? code : nil
        }
        score += min(Double(validAirports.count) * 0.15, 0.3)
        
        // Has location data: +0.1
        if event.location != nil && !event.location!.isEmpty {
            score += 0.1
        }
        
        // Duration looks like a flight (1-24 hours): +0.1
        if let start = event.start.asDate, let end = event.end.asDate {
            let duration = end.timeIntervalSince(start)
            if duration >= 3600 && duration <= 86400 {
                score += 0.1
            }
        }
        
        return min(score, 1.0) // Cap at 1.0
    }
}

// MARK: - Data Models

struct GoogleCalendarEvent: Codable, Identifiable {
    let id: String
    let summary: String
    let description: String?
    let location: String?
    let start: EventDateTime
    let end: EventDateTime
    let created: String?
    let updated: String?
}

struct EventDateTime: Codable {
    let dateTime: String?
    let date: String?
    let timeZone: String?
    
    var asDate: Date? {
        if let dateTime = dateTime {
            // Try ISO8601 with timezone
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateTime) {
                return date
            }
            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: dateTime)
        }
        return nil
    }
}

struct CalendarEventsResponse: Codable {
    let items: [GoogleCalendarEvent]
    let nextPageToken: String?
}

enum CalendarAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case unauthorized
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error \(code)"
        case .unauthorized:
            return "Authorization expired - please sign in again"
        case .decodingError:
            return "Failed to parse server response"
        }
    }
}
