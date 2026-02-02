//
//  FlightTimelineEntry.swift
//  GoFastWidget
//
//  Timeline entry model for the widget, containing flight data and urgency level.
//

import WidgetKit
import Foundation

// MARK: - Flight State

/// Represents the current state of a flight based on time until departure
/// Controls what information is displayed in the widget
enum FlightState {
    case upcoming        // > 24h until departure - purely informational
    case prepare         // < 24h but not yet time to leave - awareness mode
    case goMode          // < travelTime + buffer - action required NOW
    
    /// Calculate flight state based on departure time and leave time
    /// - Parameters:
    ///   - flight: The flight to evaluate
    ///   - leaveTime: Calculated time when user should leave
    ///   - timeUntilDeparture: Seconds until flight departure
    /// - Returns: Appropriate FlightState for current time
    static func from(flight: Flight, leaveTime: Date?, timeUntilDeparture: TimeInterval) -> FlightState {
        let twentyFourHours: TimeInterval = 24 * 60 * 60
        let goModeThreshold = TravelConfig.transportDuration + TravelConfig.buffer
        
        // First: Do I have a leave time?
        guard let leaveTime = leaveTime else {
            return timeUntilDeparture > twentyFourHours ? .upcoming : .prepare
        }
        
        // Second: Am I in Go Mode? (Go Mode always takes priority)
        let timeUntilLeave = leaveTime.timeIntervalSinceNow
        if timeUntilLeave <= goModeThreshold {
            return .goMode
        }
        
        // Third: Am I within 24h?
        if timeUntilDeparture <= twentyFourHours {
            return .prepare
        }
        
        // Otherwise -> Upcoming
        return .upcoming
    }
    
    /// Micro-copy label for the state (speaks to the user)
    var label: String {
        switch self {
        case .upcoming:
            return "Upcoming flight"
        case .prepare:
            return "Flight today"
        case .goMode:
            return "Time to leave"
        }
    }
}

// MARK: - Travel Configuration

/// Configurable travel constants (for future Pro customization)
struct TravelConfig {
    /// Transport duration to airport (45 minutes default)
    static let transportDuration: TimeInterval = 45 * 60
    
    /// Buffer time before leaving (15 minutes default)
    static let buffer: TimeInterval = 15 * 60
}

// MARK: - Urgency Level

/// Represents the urgency level for departure, affecting visual indicators and refresh frequency
enum UrgencyLevel: String, Codable {
    case relaxed   // > 90 min - green accent
    case soon      // 30-90 min - orange/yellow accent  
    case urgent    // < 30 min - red accent
    
    /// Calculate urgency from time until leave
    static func fromTimeInterval(_ interval: TimeInterval) -> UrgencyLevel {
        let minutes = interval / 60
        if minutes < 30 {
            return .urgent
        } else if minutes < 90 {
            return .soon
        } else {
            return .relaxed
        }
    }
    
    /// Color for visual accent (not full background)
    var accentColor: String {
        switch self {
        case .relaxed:
            return "relaxedGreen"
        case .soon:
            return "soonOrange"
        case .urgent:
            return "urgentRed"
        }
    }
    
    /// SF Symbol icon representing urgency
    var iconName: String {
        switch self {
        case .relaxed:
            return "checkmark.circle.fill"
        case .soon:
            return "exclamationmark.circle.fill"
        case .urgent:
            return "exclamationmark.triangle.fill"
        }
    }
}

// MARK: - Timeline Entry

/// Timeline entry containing flight information for widget display
struct FlightTimelineEntry: TimelineEntry {
    let date: Date
    let flight: Flight?
    let leaveTime: Date?
    let timeUntilLeave: TimeInterval?
    let timeUntilDeparture: TimeInterval?
    let urgencyLevel: UrgencyLevel
    let flightState: FlightState
    let isMockData: Bool
    
    /// Creates an entry with calculated urgency and flight state
    init(
        date: Date,
        flight: Flight?,
        leaveTime: Date?,
        timeUntilLeave: TimeInterval?,
        timeUntilDeparture: TimeInterval?,
        isMockData: Bool = false
    ) {
        self.date = date
        self.flight = flight
        self.leaveTime = leaveTime
        self.timeUntilLeave = timeUntilLeave
        self.timeUntilDeparture = timeUntilDeparture
        self.isMockData = isMockData
        
        // Calculate flight state based on departure and leave times
        if let flight = flight, let timeUntilDeparture = timeUntilDeparture {
            self.flightState = FlightState.from(
                flight: flight,
                leaveTime: leaveTime,
                timeUntilDeparture: timeUntilDeparture
            )
        } else {
            self.flightState = .upcoming
        }
        
        // Calculate urgency based on time until leave (only meaningful in Go Mode)
        if let timeUntilLeave = timeUntilLeave, timeUntilLeave > 0 {
            self.urgencyLevel = UrgencyLevel.fromTimeInterval(timeUntilLeave)
        } else {
            self.urgencyLevel = .relaxed
        }
    }
    
    /// Empty state entry (no flights)
    static func empty(date: Date) -> FlightTimelineEntry {
        FlightTimelineEntry(
            date: date,
            flight: nil,
            leaveTime: nil,
            timeUntilLeave: nil,
            timeUntilDeparture: nil,
            isMockData: false
        )
    }
}
