//
//  SharedDataService.swift
//  GoFast
//
//  Service for sharing flight data between app and widget via App Groups.
//

import Foundation
import WidgetKit

/// Service for reading and writing flight data to App Groups
/// Enables data sharing between the main app and widget extension
class SharedDataService {
    
    // MARK: - Singleton
    
    static let shared = SharedDataService()
    
    // MARK: - Properties
    
    /// App Group identifier - must match in both app and widget targets
    private let appGroupId = "group.com.gofast.shared"
    
    /// UserDefaults instance for the App Group
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }
    
    /// Keys for stored data
    private enum Keys {
        static let currentFlight = "currentFlight"
        static let lastUpdate = "lastUpdate"
        static let isMockData = "isMockData"
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Saves a flight to App Groups for widget access
    /// - Parameter flight: The flight to save
    func saveFlight(_ flight: Flight) {
        guard let defaults = sharedDefaults else {
            print("[SharedDataService] Failed to access shared UserDefaults")
            return
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(flight)
            defaults.set(data, forKey: Keys.currentFlight)
            defaults.set(Date(), forKey: Keys.lastUpdate)
            defaults.set(flight.detectionSource == .manualEntry, forKey: Keys.isMockData)
            
            print("[SharedDataService] Flight saved: \(flight.flightNumber ?? "Unknown")")
            
            // Trigger widget reload
            reloadWidget()
        } catch {
            print("[SharedDataService] Failed to encode flight: \(error)")
        }
    }
    
    /// Loads the currently saved flight from App Groups
    /// - Returns: The saved Flight object, or nil if none exists
    func loadFlight() -> Flight? {
        guard let defaults = sharedDefaults else {
            print("[SharedDataService] Failed to access shared UserDefaults")
            return nil
        }
        
        guard let data = defaults.data(forKey: Keys.currentFlight) else {
            print("[SharedDataService] No flight data found")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let flight = try decoder.decode(Flight.self, from: data)
            print("[SharedDataService] Flight loaded: \(flight.flightNumber ?? "Unknown")")
            return flight
        } catch {
            print("[SharedDataService] Failed to decode flight: \(error)")
            return nil
        }
    }
    
    /// Clears the saved flight data
    func clearFlight() {
        guard let defaults = sharedDefaults else { return }
        
        defaults.removeObject(forKey: Keys.currentFlight)
        defaults.removeObject(forKey: Keys.lastUpdate)
        defaults.removeObject(forKey: Keys.isMockData)
        
        print("[SharedDataService] Flight data cleared")
        
        // Trigger widget reload to show empty state
        reloadWidget()
    }
    
    /// Returns the timestamp of the last update
    func lastUpdateTime() -> Date? {
        guard let defaults = sharedDefaults else { return nil }
        return defaults.object(forKey: Keys.lastUpdate) as? Date
    }
    
    /// Checks if the saved flight is mock data
    func isMockData() -> Bool {
        guard let defaults = sharedDefaults else { return false }
        return defaults.bool(forKey: Keys.isMockData)
    }
    
    /// Triggers a widget timeline reload
    func reloadWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "FlightWidget")
        print("[SharedDataService] Widget reload triggered")
    }
    
    /// Checks if App Groups is properly configured
    var isConfigured: Bool {
        sharedDefaults != nil
    }
}
