# Data Model

## Overview

This document defines the core data models for GoFast. All models are immutable structs using value semantics, Codable for persistence, and Equatable for comparison.

## Flight Model

```swift
struct Flight: Codable, Equatable, Identifiable {
    let id: UUID
    let flightNumber: String?
    let airline: String?
    let departureAirport: Airport
    let arrivalAirport: Airport?
    let departureTime: Date
    let arrivalTime: Date?
    let detectionSource: DetectionSource
    let status: FlightStatus
    let detectedAt: Date
    let terminal: String?
    let gate: String?
}
```

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `id` | UUID | Unique identifier for the flight |
| `flightNumber` | String? | Optional flight number (e.g., "AA123", "KL 456") |
| `airline` | String? | Optional airline name or code |
| `departureAirport` | Airport | Origin airport (always required) |
| `arrivalAirport` | Airport? | Destination airport (optional for MVP) |
| `departureTime` | Date | Scheduled departure time in local timezone |
| `arrivalTime` | Date? | Scheduled arrival (optional) |
| `detectionSource` | DetectionSource | How the flight was found (see below) |
| `status` | FlightStatus | Current flight state (upcoming, departed, etc.) |
| `detectedAt` | Date | When GoFast first detected this flight |
| `terminal` | String? | Terminal information if available |
| `gate` | String? | Gate information if available |

### DetectionSource Enum

```swift
enum DetectionSource: String, Codable {
    case structuredEvent    // Event with airport codes + flight keywords
    case keywordMatch       // Event with keywords only (flight, vuelo, etc.)
    case flightNumberRegex  // Regex match on flight number pattern
    case manualEntry        // User-added manually (post-MVP)
}
```

### FlightStatus Enum

```swift
enum FlightStatus: String, Codable {
    case upcoming           // Flight in future, primary focus
    case departed           // Flight has left (hide from widget)
    case cancelled          // Flight cancelled (show alert)
    case unknown            // Status unclear
}
```

## Airport Model

```swift
struct Airport: Codable, Equatable, Identifiable {
    let id: String          // IATA code (e.g., "DMK", "MAD")
    let name: String        // Full name (e.g., "Don Mueang International")
    let city: String        // City name
    let country: String     // Country code (ISO 3166-1 alpha-2)
    let latitude: Double    // For location calculations
    let longitude: Double   // For location calculations
    let timezone: String    // IANA timezone identifier
    let isInternational: Bool  // Derived from typical routes
    let terminals: [String]?   // Known terminal names
}
```

### Key Airports Database

MVP includes a hardcoded database of major airports (~500 worldwide). Post-MVP may fetch from API.

**International vs Domestic Detection Logic:**

Airports are classified based on typical route patterns:
- **International hubs**: LHR, JFK, CDG, NRT, DMK, SIN, etc.
- **Domestic-focused**: Most regional airports

At runtime, we determine if a specific flight is international by:
1. Comparing departure and arrival airport countries (if arrival known)
2. Checking if departure airport is primarily international hub (if arrival unknown)
3. Defaulting to domestic if uncertain (safer for time calculations)

## TransportOption Model

```swift
struct TransportOption: Codable, Equatable, Identifiable {
    let id: UUID
    let mode: TransportMode
    let estimatedDuration: TimeInterval  // In seconds
    let estimatedArrivalTime: Date       // Current time + duration
    let costEstimate: CostEstimate?      // Optional pricing
    let reliabilityScore: Double         // 0.0 - 1.0 based on traffic patterns
    let deepLink: URL?                   // URL to open in external app
    let isAvailable: Bool                // Can this option be used right now?
    let requiresApp: String?             // App bundle ID required (if any)
}
```

### TransportMode Enum

```swift
enum TransportMode: String, Codable, CaseIterable {
    case car           // Personal vehicle
    case taxi          // Taxi/ride-hail (Uber, Grab, etc.)
    case publicTransit // Train, subway, bus
    case shuttle       // Airport shuttle service
}
```

### CostEstimate Enum

```swift
enum CostEstimate: Codable, Equatable {
    case free                    // Public transit, personal car
    case fixed(amount: Double, currency: String)   // Flat rate
    case range(min: Double, max: Double, currency: String)  // Variable
}
```

## Detection Logic

### Priority System

Flight detection uses a 3-tier priority system when scanning calendar events:

**Tier 1: Structured Event (Highest Confidence)**
```
Requirements:
- Contains IATA airport code (e.g., "DMK", "MAD")
- Contains flight-related keywords: "Flight", "Vuelo", "Departure", 
  "Airlines", "Travel", "Trip"
- Created by Google Calendar, Apple Calendar, or airline apps

Confidence: 95%
Source: .structuredEvent
```

**Tier 2: Keyword Match (Medium Confidence)**
```
Requirements:
- Contains flight-related keywords (without airport code)
- Event title or notes include: "flight", "vuelo", "departure",
  "airport", "terminal", "boarding"
- Time window within 48 hours (heuristic for travel events)

Confidence: 60%
Source: .keywordMatch
```

**Tier 3: Flight Number Regex (Lowest Confidence)**
```
Requirements:
- Matches pattern: [A-Z]{2}\s?\d{2,4}
  Examples: "AA123", "KL 456", "BA789", "SQ12"
- Used as fallback only when Tier 1/2 don't match
- Cross-referenced with known airline codes

Confidence: 40%
Source: .flightNumberRegex
```

### Detection Process

```swift
func detectFlights(in events: [EKEvent]) -> [Flight] {
    var detectedFlights: [Flight] = []
    
    for event in events {
        // Tier 1: Check for airport codes + keywords
        if let flight = detectStructuredEvent(event) {
            detectedFlights.append(flight)
            continue
        }
        
        // Tier 2: Check for keywords only
        if let flight = detectKeywordEvent(event) {
            detectedFlights.append(flight)
            continue
        }
        
        // Tier 3: Check for flight number regex
        if let flight = detectFlightNumberEvent(event) {
            detectedFlights.append(flight)
            continue
        }
    }
    
    // Sort by departure time, take most imminent
    return detectedFlights.sorted { $0.departureTime < $1.departureTime }
}
```

### Airport Code Extraction

IATA codes are 3-letter uppercase codes. Detection searches:
- Event title
- Event location field
- Event notes/description
- Known patterns: "DMK Airport", "Flight to MAD", "Depart: BCN"

### Keyword Dictionary

**English**: flight, departure, airport, terminal, gate, boarding, travel, trip, airlines
**Spanish**: vuelo, salida, aeropuerto, terminal, puerta, embarque, viaje, aerolíneas
**Thai**: เที่ยวบิน, สนามบิน (transliterated in some calendars)
**Auto-detected**: Calendar language settings help prioritize keywords

## Leave Time Calculation

### Calculation Formula

```
Leave Time = Departure Time 
             - Airport Procedure Time 
             - Transport Duration 
             - User Buffer
```

### Airport Procedure Times

```swift
enum AirportProcedureTime {
    static let domesticStandard: TimeInterval = 90 * 60   // 90 minutes
    static let internationalStandard: TimeInterval = 180 * 60  // 3 hours
    
    // Pro users can customize (post-MVP feature detailed)
    static let checkInDeadline: TimeInterval = 45 * 60    // Before departure
    static let securityStandard: TimeInterval = 30 * 60   // Security screening
    static let gateArrivalBuffer: TimeInterval = 15 * 60  // Be at gate before boarding
}
```

### Transport Duration

Obtained from Apple Maps API (MapKit/MKDirections):
- Real-time traffic when available
- Fallback to historical averages
- Multiple route options (fastest, shortest)

### User Buffer

**Free Tier**: Automatic buffer based on flight type
- Domestic: 15 minutes extra
- International: 30 minutes extra

**Pro Tier**: Customizable buffer per transport mode
- Range: 0 - 60 minutes
- Per-location settings (home vs hotel)

## Data Persistence

### App Groups Configuration

```
Group ID: group.com.gofast.shared
Container: Shared UserDefaults + FileManager container
```

### Stored Data

```swift
// UserDefaults keys
let kDetectedFlights = "detected_flights"        // [Flight] JSON
let kLastUpdateTime = "last_update_time"         // Date
let kUserSettings = "user_settings"              // Settings JSON
let kProFeaturesEnabled = "pro_features_enabled" // Bool
```

### Update Strategy

- Save to App Groups after every flight detection cycle
- Widget reads from App Groups on every timeline refresh
- Background app refresh updates flight detection every 15 minutes
- Manual pull-to-refresh triggers immediate update

## Validation & Error Handling

### Flight Validation

A detected flight is valid if:
- Departure time is in the future (or within last 2 hours for "departed" status)
- Departure airport is recognized (exists in airport database)
- Departure time is within reasonable range (not 6 months in future)

### Data Integrity

- All dates stored in UTC, displayed in local timezone
- Airport timezone used for departure time display
- Graceful degradation: unknown airports default to domestic timing
- Duplicate detection: same flight number + departure time = same flight

## Extension Considerations

### Codable Compliance

All models use Codable for:
- App Groups JSON persistence
- Future cloud sync (post-MVP)
- Debugging and logging

### Equatable

All models implement Equatable for:
- Detecting data changes (trigger widget updates)
- SwiftUI view diffing
- Unit test assertions

### Identifiable

Models use stable identifiers:
- Flight: UUID (generated on detection)
- Airport: IATA code (stable worldwide)
- TransportOption: UUID (generated per calculation)
