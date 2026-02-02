//
//  MockFlightData.swift
//  GoFast
//
//  Generates mock flight data for testing widget without real calendar access.
//

import Foundation

/// Utility for generating mock flight data
struct MockFlightData {
    
    /// Generates a mock flight (AA123 from DMK) for testing
    /// - Returns: A Flight instance with realistic data
    static func generate() -> Flight {
        // Use DMK (Don Mueang) as departure airport
        guard let dmkAirport = Airport.find(byIATACode: "DMK") else {
            // Fallback if airport not found (shouldn't happen in production)
            print("[MockFlightData] ❌ DMK airport not found in database")
            // Return a minimal flight with placeholder data
            let unknownAirport = Airport(
                iataCode: "UNK",
                name: "Unknown Airport",
                city: "Unknown",
                countryCode: "XX",
                latitude: 0.0,
                longitude: 0.0,
                timezoneIdentifier: "UTC",
                isInternationalHub: false
            )
            return Flight(
                flightNumber: "AA123",
                airline: "American Airlines",
                departureAirport: unknownAirport,
                arrivalAirport: nil,
                departureTime: Date().addingTimeInterval(24 * 3600),
                arrivalTime: nil,
                detectionSource: .manualEntry,
                terminal: "Terminal 1",
                gate: "Gate A12"
            )
        }
        
        // Create a flight departing tomorrow at 5:30 PM
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        var components = Calendar.current.dateComponents([.year, .month, .day], from: tomorrow)
        components.hour = 17
        components.minute = 30
        let departureTime = Calendar.current.date(from: components)!
        
        return Flight(
            flightNumber: "AA123",
            airline: "American Airlines",
            departureAirport: dmkAirport,
            arrivalAirport: nil, // Can add arrival airport later
            departureTime: departureTime,
            arrivalTime: nil,
            detectionSource: .manualEntry, // Mark as manual for mock data
            terminal: "Terminal 1",
            gate: "Gate A12"
        )
    }
    
    /// Generates a mock flight with custom parameters
    /// - Parameters:
    ///   - flightNumber: Flight number (e.g., "SQ456")
    ///   - airportCode: Departure airport IATA code
    ///   - hoursFromNow: Hours until departure
    /// - Returns: Customized Flight instance
    static func generateCustom(
        flightNumber: String = "SQ456",
        airportCode: String = "SIN",
        hoursFromNow: Double = 24
    ) -> Flight? {
        guard let airport = Airport.find(byIATACode: airportCode) else {
            print("[MockFlightData] Airport \(airportCode) not found")
            return nil
        }
        
        let departureTime = Date().addingTimeInterval(hoursFromNow * 3600)
        
        return Flight(
            flightNumber: flightNumber,
            airline: nil,
            departureAirport: airport,
            arrivalAirport: nil,
            departureTime: departureTime,
            arrivalTime: nil,
            detectionSource: .manualEntry
        )
    }
    
    /// Array of mock flights for testing multiple scenarios
    static var sampleFlights: [Flight] {
        [
            generate(),
            generateCustom(flightNumber: "SQ321", airportCode: "SIN", hoursFromNow: 48),
            generateCustom(flightNumber: "BA028", airportCode: "LHR", hoursFromNow: 12),
            generateCustom(flightNumber: "JL005", airportCode: "NRT", hoursFromNow: 6)
        ].compactMap { $0 }
    }
}
