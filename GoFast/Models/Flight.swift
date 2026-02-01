//
//  Flight.swift
//  GoFast
//
//  Core domain model representing a detected flight with all relevant
//  details including departure information, detection metadata, and status.
//

import Foundation

/// Represents a detected flight with all necessary information for calculating
/// departure time and displaying in widgets. Flights are immutable value types
/// created by the FlightDetectionService and persisted via App Groups.
struct Flight: Codable, Equatable, Identifiable, Hashable {
    
    // MARK: - Identification
    
    /// Unique identifier generated when flight is first detected
    let id: UUID
    
    /// Optional flight number (e.g., "AA123", "KL 456", "SQ12")
    /// May be nil if extracted from unstructured calendar events
    let flightNumber: String?
    
    /// Optional airline name or IATA code
    let airline: String?
    
    // MARK: - Route
    
    /// Departure airport (always required)
    let departureAirport: Airport
    
    /// Arrival airport (optional for MVP - may not be extracted from all events)
    let arrivalAirport: Airport?
    
    // MARK: - Timing
    
    /// Scheduled departure time in the departure airport's local timezone
    let departureTime: Date
    
    /// Scheduled arrival time (optional)
    let arrivalTime: Date?
    
    // MARK: - Detection Metadata
    
    /// Source method used to detect this flight from calendar events
    let detectionSource: DetectionSource
    
    /// Timestamp when GoFast first detected this flight
    let detectedAt: Date
    
    // MARK: - Airport Details
    
    /// Terminal information if extracted from calendar event
    let terminal: String?
    
    /// Gate information if extracted from calendar event
    let gate: String?
    
    /// Seat information if extracted from calendar event
    let seat: String?
    
    // MARK: - Status
    
    /// Current flight status computed relative to current time
    var status: FlightStatus {
        FlightStatus.forDate(departureTime)
    }
    
    /// Whether this flight is likely international based on route
    var isInternational: Bool {
        departureAirport.isLikelyInternational(destinationAirport: arrivalAirport)
    }
    
    // MARK: - Computed Properties
    
    /// Display title for the flight (flight number or route description)
    var displayTitle: String {
        if let flightNumber = flightNumber {
            return flightNumber
        }
        if let arrival = arrivalAirport {
            return "\(departureAirport.id) → \(arrival.id)"
        }
        return "Flight to \(departureAirport.city)"
    }
    
    /// Formatted departure time for display
    var formattedDepartureTime: String {
        let formatter = DateFormatter()
        formatter.timeZone = departureAirport.timezoneOrCurrent()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: departureTime)
    }
    
    /// Time remaining until departure
    var timeUntilDeparture: TimeInterval {
        departureTime.timeIntervalSinceNow
    }
    
    /// Whether the flight is within the next 24 hours (priority display)
    var isImminent: Bool {
        let hoursUntilDeparture = timeUntilDeparture / 3600
        return hoursUntilDeparture > 0 && hoursUntilDeparture <= 24
    }
    
    /// Unique identifier combining flight number and departure time for deduplication
    var deduplicationKey: String {
        let number = flightNumber ?? "unknown"
        let time = ISO8601DateFormatter().string(from: departureTime)
        return "\(number)_\(time)"
    }
    
    // MARK: - Initialization
    
    /// Creates a new Flight instance.
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - flightNumber: Optional flight number
    ///   - airline: Optional airline name/code
    ///   - departureAirport: Origin airport (required)
    ///   - arrivalAirport: Optional destination airport
    ///   - departureTime: Scheduled departure time
    ///   - arrivalTime: Optional scheduled arrival time
    ///   - detectionSource: Method used to detect this flight
    ///   - detectedAt: When detection occurred (defaults to now)
    ///   - terminal: Optional terminal information
    ///   - gate: Optional gate information
    ///   - seat: Optional seat information
    init(
        id: UUID = UUID(),
        flightNumber: String? = nil,
        airline: String? = nil,
        departureAirport: Airport,
        arrivalAirport: Airport? = nil,
        departureTime: Date,
        arrivalTime: Date? = nil,
        detectionSource: DetectionSource,
        detectedAt: Date = Date(),
        terminal: String? = nil,
        gate: String? = nil,
        seat: String? = nil
    ) {
        self.id = id
        self.flightNumber = flightNumber?.uppercased()
        self.airline = airline
        self.departureAirport = departureAirport
        self.arrivalAirport = arrivalAirport
        self.departureTime = departureTime
        self.arrivalTime = arrivalTime
        self.detectionSource = detectionSource
        self.detectedAt = detectedAt
        self.terminal = terminal
        self.gate = gate
        self.seat = seat
    }
}

// MARK: - Detection Source

/// Indicates the method used to detect a flight from calendar events.
/// Used for confidence scoring and debugging.
enum DetectionSource: String, Codable, CaseIterable {
    /// High confidence: Event contains IATA airport codes AND flight keywords
    /// Examples: "Flight to DMK", "AA123 Departure", "Vuelo MAD-BCN"
    case structuredEvent
    
    /// Medium confidence: Event contains flight keywords but no airport codes
    /// Examples: "Flight to Bangkok", "Departure", "Airport pickup"
    case keywordMatch
    
    /// Low confidence: Event matches flight number regex pattern
    /// Examples: "Meeting with AA123", "Project KL456 review"
    /// Used as fallback when other methods fail
    case flightNumberRegex
    
    /// User manually entered flight (post-MVP feature)
    case manualEntry
    
    /// Confidence level for this detection source (0.0 - 1.0)
    var confidence: Double {
        switch self {
        case .structuredEvent:
            return 0.95
        case .keywordMatch:
            return 0.60
        case .flightNumberRegex:
            return 0.40
        case .manualEntry:
            return 1.0
        }
    }
    
    /// Display description for debugging and analytics
    var displayName: String {
        switch self {
        case .structuredEvent:
            return "Structured Event"
        case .keywordMatch:
            return "Keyword Match"
        case .flightNumberRegex:
            return "Flight Number Pattern"
        case .manualEntry:
            return "Manual Entry"
        }
    }
}

// MARK: - Flight Status

/// Represents the current state of a flight relative to the current time.
enum FlightStatus: String, Codable {
    /// Flight is in the future and is the primary focus for departure calculation
    case upcoming
    
    /// Flight has already departed (within last 2 hours)
    /// Shown in history but not in departure widget
    case departed
    
    /// Flight was cancelled (if information available from calendar)
    case cancelled
    
    /// Status cannot be determined
    case unknown
    
    /// Determines the status for a given departure date
    /// - Parameter departureDate: The scheduled departure time
    /// - Returns: Appropriate FlightStatus based on current time
    static func forDate(_ departureDate: Date) -> FlightStatus {
        let now = Date()
        let timeUntilDeparture = departureDate.timeIntervalSince(now)
        let timeSinceDeparture = now.timeIntervalSince(departureDate)
        
        // Flight hasn't departed yet
        if timeUntilDeparture > 0 {
            return .upcoming
        }
        
        // Flight departed within last 2 hours (grace period)
        if timeSinceDeparture <= 7200 { // 2 hours = 7200 seconds
            return .departed
        }
        
        // Flight departed more than 2 hours ago
        return .unknown
    }
    
    /// Whether this flight should be shown in the departure widget
    var isRelevantForDeparture: Bool {
        self == .upcoming
    }
    
    /// User-friendly display text
    var displayText: String {
        switch self {
        case .upcoming:
            return "Upcoming"
        case .departed:
            return "Departed"
        case .cancelled:
            return "Cancelled"
        case .unknown:
            return "Unknown"
        }
    }
}

// MARK: - Flight Extensions

extension Flight {
    
    /// Standard airport arrival procedure times based on flight type.
    /// These are used by LeaveTimeCalculator to determine when user should arrive at airport.
    enum AirportProcedureTime {
        /// Standard domestic flight procedure time: 90 minutes
        static let domesticStandard: TimeInterval = 90 * 60
        
        /// Standard international flight procedure time: 3 hours
        static let internationalStandard: TimeInterval = 180 * 60
        
        /// Latest check-in time before departure (typically 45-60 minutes)
        static let checkInDeadline: TimeInterval = 45 * 60
        
        /// Time needed for security screening
        static let securityStandard: TimeInterval = 30 * 60
        
        /// Buffer time to reach gate after security
        static let gateArrivalBuffer: TimeInterval = 15 * 60
    }
    
    /// Calculates the recommended airport arrival time based on flight type.
    /// This is the time user should be at the airport (not when to leave home).
    /// - Returns: Recommended arrival time at airport
    func recommendedAirportArrivalTime() -> Date {
        let procedureTime = isInternational
            ? AirportProcedureTime.internationalStandard
            : AirportProcedureTime.domesticStandard
        
        return departureTime.addingTimeInterval(-procedureTime)
    }
    
    /// Determines if this flight is more urgent than another.
    /// Used for selecting the primary flight to display in widgets (Free tier).
    /// - Parameter other: Flight to compare against
    /// - Returns: True if this flight should be prioritized
    func isMoreUrgent(than other: Flight) -> Bool {
        // Earlier departure time takes priority
        if departureTime != other.departureTime {
            return departureTime < other.departureTime
        }
        
        // If same time, higher confidence detection takes priority
        return detectionSource.confidence > other.detectionSource.confidence
    }
}

// MARK: - Flight Filtering

extension Array where Element == Flight {
    
    /// Filters to only upcoming flights sorted by departure time
    var upcoming: [Flight] {
        filter { $0.status == .upcoming }
            .sorted { $0.departureTime < $1.departureTime }
    }
    
    /// Returns the most imminent upcoming flight (the one to leave for next)
    var mostImminent: Flight? {
        upcoming.first
    }
    
    /// Filters to flights departing within specified hours
    /// - Parameter hours: Time window in hours
    /// - Returns: Flights departing within the time window
    func departingWithin(hours: Double) -> [Flight] {
        upcoming.filter { flight in
            let hoursUntilDeparture = flight.timeUntilDeparture / 3600
            return hoursUntilDeparture <= hours
        }
    }
    
    /// Removes duplicate flights based on deduplication key
    /// Keeps the flight with highest confidence detection source
    /// - Returns: Deduplicated array
    func deduplicated() -> [Flight] {
        let grouped = Dictionary(grouping: self) { $0.deduplicationKey }
        return grouped.compactMap { _, flights in
            flights.max { $0.detectionSource.confidence < $1.detectionSource.confidence }
        }
    }
}
