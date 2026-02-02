//
//  FlightTimelineProvider.swift
//  GoFastWidget
//
//  Timeline provider with adaptive refresh rates based on departure urgency.
//

import WidgetKit
import SwiftUI

/// Timeline provider that generates entries with adaptive refresh intervals
/// based on how close the departure time is.
struct FlightTimelineProvider: TimelineProvider {
    
    typealias Entry = FlightTimelineEntry
    
    /// Service for reading shared flight data
    private let sharedDataService = SharedDataService.shared
    
    // MARK: - TimelineProvider Methods
    
    func placeholder(in context: Context) -> FlightTimelineEntry {
        // Placeholder shown when widget is first added
        let mockFlight = MockFlightData.generate()
        let departureTime = mockFlight.departureTime
        let timeUntilDeparture = departureTime.timeIntervalSinceNow
        
        return FlightTimelineEntry(
            date: Date(),
            flight: mockFlight,
            leaveTime: Date().addingTimeInterval(45 * 60),
            timeUntilLeave: 45 * 60,
            timeUntilDeparture: timeUntilDeparture,
            isMockData: true
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (FlightTimelineEntry) -> ()) {
        // Snapshot for widget gallery and previews
        let entry = loadCurrentEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let entry = loadCurrentEntry()
        
        // Determine refresh interval based on urgency
        let refreshInterval = calculateRefreshInterval(for: entry)
        let refreshDate = currentDate.addingTimeInterval(refreshInterval)
        
        // Generate timeline entries
        var entries: [FlightTimelineEntry] = []
        
        // Add current entry
        entries.append(entry)
        
        // Add future entries based on urgency
        let numberOfEntries = calculateNumberOfEntries(for: entry)
        for i in 1..<numberOfEntries {
            let entryDate = currentDate.addingTimeInterval(Double(i) * refreshInterval)
            
            // Recalculate time values for future entries
            if let flight = entry.flight {
                let futureTimeUntilDeparture = flight.departureTime.timeIntervalSince(entryDate)
                
                if let leaveTime = entry.leaveTime {
                    let futureTimeUntilLeave = leaveTime.timeIntervalSince(entryDate)
                    let futureEntry = FlightTimelineEntry(
                        date: entryDate,
                        flight: flight,
                        leaveTime: leaveTime,
                        timeUntilLeave: futureTimeUntilLeave > 0 ? futureTimeUntilLeave : nil,
                        timeUntilDeparture: futureTimeUntilDeparture,
                        isMockData: entry.isMockData
                    )
                    entries.append(futureEntry)
                } else {
                    // No leave time calculated yet
                    let futureEntry = FlightTimelineEntry(
                        date: entryDate,
                        flight: flight,
                        leaveTime: nil,
                        timeUntilLeave: nil,
                        timeUntilDeparture: futureTimeUntilDeparture,
                        isMockData: entry.isMockData
                    )
                    entries.append(futureEntry)
                }
            } else {
                entries.append(FlightTimelineEntry.empty(date: entryDate))
            }
        }
        
        // Timeline expires and requests new data after refresh interval
        let timeline = Timeline(entries: entries, policy: .after(refreshDate))
        completion(timeline)
    }
    
    // MARK: - Helper Methods
    
    /// Loads current flight data from App Groups
    private func loadCurrentEntry() -> FlightTimelineEntry {
        // Try to load saved flight
        if let flight = sharedDataService.loadFlight() {
            // Calculate times
            let departureTime = flight.departureTime
            let timeUntilDeparture = departureTime.timeIntervalSinceNow
            
            // Calculate leave time using configured travel times
            let transportDuration = TravelConfig.transportDuration
            let bufferTime = TravelConfig.buffer
            let airportProcedureTime: TimeInterval = flight.isInternational ? 180 * 60 : 90 * 60
            
            let leaveTime = departureTime
                .addingTimeInterval(-airportProcedureTime)
                .addingTimeInterval(-transportDuration)
                .addingTimeInterval(-bufferTime)
            
            let timeUntilLeave = leaveTime.timeIntervalSinceNow
            
            return FlightTimelineEntry(
                date: Date(),
                flight: flight,
                leaveTime: leaveTime,
                timeUntilLeave: timeUntilLeave > 0 ? timeUntilLeave : nil,
                timeUntilDeparture: timeUntilDeparture,
                isMockData: flight.detectionSource == .manualEntry
            )
        }
        
        // No flight data available
        return FlightTimelineEntry.empty(date: Date())
    }
    
    /// Calculates appropriate refresh interval based on urgency
    private func calculateRefreshInterval(for entry: FlightTimelineEntry) -> TimeInterval {
        // Use flight state to determine refresh rate
        switch entry.flightState {
        case .goMode:
            // Refresh frequently during Go Mode
            return 60 // 1 minute
        case .prepare:
            // Moderate refresh during Prepare
            return 5 * 60 // 5 minutes
        case .upcoming:
            // Relaxed refresh for Upcoming
            return 15 * 60 // 15 minutes
        }
    }
    
    /// Calculates how many future entries to generate
    private func calculateNumberOfEntries(for entry: FlightTimelineEntry) -> Int {
        guard entry.flight != nil else {
            return 1 // Just one empty entry
        }
        
        let refreshInterval = calculateRefreshInterval(for: entry)
        let totalDuration: TimeInterval = 4 * 60 * 60 // 4 hours lookahead
        
        return Int(totalDuration / refreshInterval)
    }
}
