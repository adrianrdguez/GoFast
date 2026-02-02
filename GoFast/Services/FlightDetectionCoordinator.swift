//
//  FlightDetectionCoordinator.swift
//  GoFast
//
//  Unified flight detection coordinator that manages multiple data sources.
//  Prioritizes Google Calendar as primary, Apple Calendar as fallback.
//

import Foundation

/// Coordinates flight detection across multiple data sources with priority ordering
class FlightDetectionCoordinator {
    static let shared = FlightDetectionCoordinator()
    
    private let sources: [FlightDataSource] = [
        GoogleCalendarDataSource(),  // Primary: Google Calendar
        AppleCalendarDataSource()     // Fallback: Apple Calendar
    ]
    
    /// Information about the active data source
    struct SourceInfo {
        let name: String
        let lastSync: Date?
        let isAvailable: Bool
        let isPrimary: Bool
    }
    
    /// Gets information about all available data sources
    var availableSources: [SourceInfo] {
        sources.enumerated().map { index, source in
            SourceInfo(
                name: source.sourceName,
                lastSync: source.lastSyncDate,
                isAvailable: source.isAvailable,
                isPrimary: index == 0
            )
        }
    }
    
    /// The primary (Google Calendar) data source
    var primarySource: FlightDataSource? {
        sources.first
    }
    
    /// Whether the primary source (Google) is available
    var isPrimarySourceAvailable: Bool {
        primarySource?.isAvailable ?? false
    }
    
    /// Fetches flights from the best available source
    /// Priority: Google Calendar → Apple Calendar → Empty
    func fetchFlights() async throws -> [Flight] {
        var lastError: Error?
        
        // Try sources in order of priority
        for (index, source) in sources.enumerated() where source.isAvailable {
            do {
                let flights = try await source.fetchFlights()
                
                // Log which source we're using
                let sourceType = index == 0 ? "Primary" : "Fallback"
                print("[FlightDetection] Using \(sourceType): \(source.sourceName) - found \(flights.count) flights")
                
                return flights
            } catch {
                print("[FlightDetection] \(source.sourceName) failed: \(error.localizedDescription)")
                lastError = error
                continue
            }
        }
        
        // No source available
        if let error = lastError {
            throw error
        } else {
            throw FlightDetectionCoordinatorError.noDataSourceAvailable
        }
    }
    
    /// Fetches flights from a specific source by name
    func fetchFlights(fromSource sourceName: String) async throws -> [Flight] {
        guard let source = sources.first(where: { $0.sourceName == sourceName }) else {
            throw FlightDetectionCoordinatorError.unknownSource(sourceName)
        }
        
        guard source.isAvailable else {
            throw FlightDetectionCoordinatorError.sourceNotAvailable(sourceName)
        }
        
        return try await source.fetchFlights()
    }
    
    /// Checks if any data source is available
    var hasAvailableSource: Bool {
        sources.contains { $0.isAvailable }
    }
    
    /// Returns a user-friendly status message
    var statusMessage: String {
        if let google = sources.first(where: { $0.sourceName == "Google Calendar" }), google.isAvailable {
            if let lastSync = google.lastSyncDate {
                let formatter = RelativeDateTimeFormatter()
                return "Connected to Google Calendar (synced \(formatter.localizedString(for: lastSync, relativeTo: Date())))"
            }
            return "Connected to Google Calendar"
        } else if let apple = sources.first(where: { $0.sourceName == "Apple Calendar" }), apple.isAvailable {
            return "Using Apple Calendar (limited details)"
        } else {
            return "No calendar connected"
        }
    }
    
    /// Disconnects all data sources (signs out)
    func disconnectAll() {
        // Sign out of Google
        GoogleCalendarAuthService.shared.signOut()
        
        // Clear sync dates
        UserDefaults.standard.removeObject(forKey: "com.gofast.google.lastSync")
        UserDefaults.standard.removeObject(forKey: "com.gofast.apple.lastSync")
        
        print("[FlightDetection] All sources disconnected")
    }
}

// MARK: - Errors

enum FlightDetectionCoordinatorError: Error, LocalizedError {
    case noDataSourceAvailable
    case unknownSource(String)
    case sourceNotAvailable(String)
    
    var errorDescription: String? {
        switch self {
        case .noDataSourceAvailable:
            return "No calendar data source available. Please connect Google Calendar or grant Apple Calendar access."
        case .unknownSource(let name):
            return "Unknown data source: \(name)"
        case .sourceNotAvailable(let name):
            return "\(name) is not available or not authorized"
        }
    }
}
