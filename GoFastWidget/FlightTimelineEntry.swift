//
//  FlightTimelineEntry.swift
//  GoFastWidget
//
//  Timeline entry model for the widget, containing flight data and urgency level.
//

import WidgetKit
import Foundation

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

/// Timeline entry containing flight information for widget display
struct FlightTimelineEntry: TimelineEntry {
    let date: Date
    let flight: Flight?
    let leaveTime: Date?
    let timeUntilLeave: TimeInterval?
    let urgencyLevel: UrgencyLevel
    let isMockData: Bool
    
    /// Creates an entry with calculated urgency
    init(
        date: Date,
        flight: Flight?,
        leaveTime: Date?,
        timeUntilLeave: TimeInterval?,
        isMockData: Bool = false
    ) {
        self.date = date
        self.flight = flight
        self.leaveTime = leaveTime
        self.timeUntilLeave = timeUntilLeave
        self.isMockData = isMockData
        
        // Calculate urgency based on time until leave
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
            isMockData: false
        )
    }
}
