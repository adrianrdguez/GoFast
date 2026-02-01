//
//  Airport.swift
//  GoFast
//
//  Core domain model representing an airport with IATA code, location data,
//  timezone information, and international/domestic classification.
//

import Foundation
import CoreLocation

/// Represents an airport with all necessary metadata for departure time calculations.
/// Airports are identified by their 3-letter IATA code and include location,
/// timezone, and classification data for determining appropriate arrival buffers.
struct Airport: Codable, Equatable, Identifiable, Hashable {
    
    // MARK: - Identification
    
    /// Unique 3-letter IATA code (e.g., "DMK", "MAD", "JFK")
    let id: String
    
    /// Full airport name (e.g., "Don Mueang International Airport")
    let name: String
    
    /// City where the airport is located
    let city: String
    
    /// Country code (ISO 3166-1 alpha-2, e.g., "TH", "ES", "US")
    let countryCode: String
    
    // MARK: - Location
    
    /// Geographic latitude for distance calculations
    let latitude: Double
    
    /// Geographic longitude for distance calculations
    let longitude: Double
    
    /// IANA timezone identifier (e.g., "Asia/Bangkok", "Europe/Madrid")
    let timezoneIdentifier: String
    
    // MARK: - Classification
    
    /// Whether this airport primarily serves international routes.
    /// Used as a heuristic when arrival airport is unknown.
    let isInternationalHub: Bool
    
    /// Known terminal identifiers at this airport (e.g., ["T1", "T2", "Domestic"])
    let terminals: [String]?
    
    // MARK: - Computed Properties
    
    /// CoreLocation coordinate for MapKit integration
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// Timezone for the airport's location
    var timezone: TimeZone? {
        TimeZone(identifier: timezoneIdentifier)
    }
    
    /// Full display name combining city and airport code
    var displayName: String {
        "\(city) (\(id))"
    }
    
    // MARK: - Initialization
    
    /// Creates a new Airport instance.
    /// - Parameters:
    ///   - iataCode: 3-letter IATA airport code
    ///   - name: Full airport name
    ///   - city: City name
    ///   - countryCode: 2-letter ISO country code
    ///   - latitude: Geographic latitude
    ///   - longitude: Geographic longitude
    ///   - timezoneIdentifier: IANA timezone string
    ///   - isInternationalHub: Whether airport primarily serves international routes
    ///   - terminals: Optional array of known terminal names
    init(
        iataCode: String,
        name: String,
        city: String,
        countryCode: String,
        latitude: Double,
        longitude: Double,
        timezoneIdentifier: String,
        isInternationalHub: Bool,
        terminals: [String]? = nil
    ) {
        self.id = iataCode.uppercased()
        self.name = name
        self.city = city
        self.countryCode = countryCode.uppercased()
        self.latitude = latitude
        self.longitude = longitude
        self.timezoneIdentifier = timezoneIdentifier
        self.isInternationalHub = isInternationalHub
        self.terminals = terminals
    }
}

// MARK: - Airport Database

extension Airport {
    
    /// Returns the timezone for this airport, falling back to current timezone if unknown
    func timezoneOrCurrent() -> TimeZone {
        timezone ?? TimeZone.current
    }
    
    /// Determines if a flight from this airport is likely international.
    /// - Parameter destinationAirport: Optional destination. If provided, compares countries.
    ///                                 If nil, uses this airport's international hub status.
    /// - Returns: Boolean indicating if flight is likely international
    func isLikelyInternational(destinationAirport: Airport? = nil) -> Bool {
        if let destination = destinationAirport {
            // Compare countries - different country = international
            return countryCode != destination.countryCode
        }
        
        // Fallback: use hub classification
        return isInternationalHub
    }
    
    /// Calculates distance to another airport in kilometers
    /// - Parameter other: Destination airport
    /// - Returns: Distance in kilometers
    func distance(to other: Airport) -> Double {
        let location1 = CLLocation(latitude: latitude, longitude: longitude)
        let location2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return location1.distance(from: location2) / 1000.0 // Convert to km
    }
}

// MARK: - Common Airports

extension Airport {
    
    /// A curated set of major international airports for MVP.
    /// In production, this would be a comprehensive database or API-backed store.
    static let majorAirports: [Airport] = [
        // Asia
        Airport(
            iataCode: "DMK",
            name: "Don Mueang International Airport",
            city: "Bangkok",
            countryCode: "TH",
            latitude: 13.9125,
            longitude: 100.6067,
            timezoneIdentifier: "Asia/Bangkok",
            isInternationalHub: true,
            terminals: ["Terminal 1", "Terminal 2"]
        ),
        Airport(
            iataCode: "BKK",
            name: "Suvarnabhumi Airport",
            city: "Bangkok",
            countryCode: "TH",
            latitude: 13.6900,
            longitude: 100.7501,
            timezoneIdentifier: "Asia/Bangkok",
            isInternationalHub: true,
            terminals: ["Main Terminal"]
        ),
        Airport(
            iataCode: "SIN",
            name: "Singapore Changi Airport",
            city: "Singapore",
            countryCode: "SG",
            latitude: 1.3644,
            longitude: 103.9915,
            timezoneIdentifier: "Asia/Singapore",
            isInternationalHub: true,
            terminals: ["Terminal 1", "Terminal 2", "Terminal 3", "Terminal 4"]
        ),
        Airport(
            iataCode: "HKG",
            name: "Hong Kong International Airport",
            city: "Hong Kong",
            countryCode: "HK",
            latitude: 22.3080,
            longitude: 113.9185,
            timezoneIdentifier: "Asia/Hong_Kong",
            isInternationalHub: true,
            terminals: ["Terminal 1"]
        ),
        Airport(
            iataCode: "NRT",
            name: "Narita International Airport",
            city: "Tokyo",
            countryCode: "JP",
            latitude: 35.7647,
            longitude: 140.3864,
            timezoneIdentifier: "Asia/Tokyo",
            isInternationalHub: true,
            terminals: ["Terminal 1", "Terminal 2", "Terminal 3"]
        ),
        
        // Europe
        Airport(
            iataCode: "MAD",
            name: "Adolfo Suárez Madrid–Barajas Airport",
            city: "Madrid",
            countryCode: "ES",
            latitude: 40.4983,
            longitude: -3.5676,
            timezoneIdentifier: "Europe/Madrid",
            isInternationalHub: true,
            terminals: ["Terminal 1", "Terminal 2", "Terminal 3", "Terminal 4", "Terminal 4S"]
        ),
        Airport(
            iataCode: "BCN",
            name: "Barcelona–El Prat Airport",
            city: "Barcelona",
            countryCode: "ES",
            latitude: 41.2974,
            longitude: 2.0833,
            timezoneIdentifier: "Europe/Madrid",
            isInternationalHub: true,
            terminals: ["Terminal 1", "Terminal 2"]
        ),
        Airport(
            iataCode: "LHR",
            name: "Heathrow Airport",
            city: "London",
            countryCode: "GB",
            latitude: 51.4700,
            longitude: -0.4543,
            timezoneIdentifier: "Europe/London",
            isInternationalHub: true,
            terminals: ["Terminal 2", "Terminal 3", "Terminal 4", "Terminal 5"]
        ),
        Airport(
            iataCode: "CDG",
            name: "Charles de Gaulle Airport",
            city: "Paris",
            countryCode: "FR",
            latitude: 49.0097,
            longitude: 2.5479,
            timezoneIdentifier: "Europe/Paris",
            isInternationalHub: true,
            terminals: ["Terminal 1", "Terminal 2A", "Terminal 2B", "Terminal 2C", "Terminal 2D", "Terminal 2E", "Terminal 2F", "Terminal 3"]
        ),
        Airport(
            iataCode: "AMS",
            name: "Amsterdam Airport Schiphol",
            city: "Amsterdam",
            countryCode: "NL",
            latitude: 52.3105,
            longitude: 4.7683,
            timezoneIdentifier: "Europe/Amsterdam",
            isInternationalHub: true,
            terminals: ["Terminal 1"]
        ),
        
        // North America
        Airport(
            iataCode: "JFK",
            name: "John F. Kennedy International Airport",
            city: "New York",
            countryCode: "US",
            latitude: 40.6413,
            longitude: -73.7781,
            timezoneIdentifier: "America/New_York",
            isInternationalHub: true,
            terminals: ["Terminal 1", "Terminal 2", "Terminal 4", "Terminal 5", "Terminal 7", "Terminal 8"]
        ),
        Airport(
            iataCode: "LAX",
            name: "Los Angeles International Airport",
            city: "Los Angeles",
            countryCode: "US",
            latitude: 33.9416,
            longitude: -118.4085,
            timezoneIdentifier: "America/Los_Angeles",
            isInternationalHub: true,
            terminals: ["Terminal 1", "Terminal 2", "Terminal 3", "Terminal 4", "Terminal 5", "Terminal 6", "Terminal 7", "Terminal 8", "Tom Bradley International Terminal"]
        ),
        Airport(
            iataCode: "SFO",
            name: "San Francisco International Airport",
            city: "San Francisco",
            countryCode: "US",
            latitude: 37.6213,
            longitude: -122.3790,
            timezoneIdentifier: "America/Los_Angeles",
            isInternationalHub: true,
            terminals: ["Terminal 1", "Terminal 2", "International Terminal G", "International Terminal A"]
        ),
    ]
    
    /// Dictionary for O(1) lookup by IATA code
    static let airportByCode: [String: Airport] = {
        Dictionary(uniqueKeysWithValues: majorAirports.map { ($0.id, $0) })
    }()
    
    /// Attempts to find an airport by its IATA code
    /// - Parameter iataCode: 3-letter IATA code (case insensitive)
    /// - Returns: Airport if found, nil otherwise
    static func find(byIATACode iataCode: String) -> Airport? {
        airportByCode[iataCode.uppercased()]
    }
    
    /// Validates if a string is a valid IATA airport code
    /// - Parameter code: String to validate
    /// - Returns: Boolean indicating if string is valid IATA code format
    static func isValidIATACode(_ code: String) -> Bool {
        let uppercaseCode = code.uppercased()
        // Must be exactly 3 uppercase letters
        guard uppercaseCode.count == 3 else { return false }
        return uppercaseCode.allSatisfy { $0.isLetter && $0.isUppercase }
    }
}
