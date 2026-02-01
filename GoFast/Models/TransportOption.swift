//
//  TransportOption.swift
//  GoFast
//
//  Core domain model representing a transport mode from user's current location
//  to the airport. Includes ETA, cost estimates, reliability scores, and deep-links
//  to external apps (Uber, Grab, Apple Maps).
//

import Foundation
import CoreLocation

/// Represents a specific transport option for getting to the airport.
/// Includes timing estimates, cost information, reliability metrics, and
/// deep-link URLs for opening external transport apps.
struct TransportOption: Codable, Equatable, Identifiable {
    
    // MARK: - Identification
    
    /// Unique identifier for this transport option instance
    let id: UUID
    
    /// Transport mode (car, taxi, public transit, etc.)
    let mode: TransportMode
    
    // MARK: - Timing
    
    /// Estimated travel duration in seconds
    let estimatedDuration: TimeInterval
    
    /// Calculated arrival time at airport (current time + duration)
    let estimatedArrivalTime: Date
    
    // MARK: - Cost
    
    /// Optional cost estimate for this transport option
    let costEstimate: CostEstimate?
    
    // MARK: - Quality Metrics
    
    /// Reliability score 0.0 - 1.0 based on traffic patterns and historical data
    /// Higher is more reliable (consistent travel times)
    let reliabilityScore: Double
    
    /// Whether this transport option is currently available
    /// (e.g., ride services may be unavailable in some areas)
    let isAvailable: Bool
    
    /// Human-readable reason if option is not available
    let unavailabilityReason: String?
    
    // MARK: - Deep Links
    
    /// Primary deep-link URL to open the transport app
    /// May be nil if no app is available for this transport mode
    let deepLink: URL?
    
    /// Bundle identifier of the app that will be opened (for checking installation)
    let requiresApp: String?
    
    /// Fallback URL if primary deep-link fails (always Apple Maps)
    let fallbackDeepLink: URL?
    
    // MARK: - Metadata
    
    /// Timestamp when this transport option was calculated
    let calculatedAt: Date
    
    /// Location used as starting point for calculation
    let originLocation: LocationCoordinate?
    
    /// Destination airport
    let destinationAirport: Airport
    
    // MARK: - Hashable
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: TransportOption, rhs: TransportOption) -> Bool {
        lhs.id == rhs.id
    }
    
    // MARK: - Computed Properties
    
    /// Formatted duration string (e.g., "45 min", "1 hr 20 min")
    var formattedDuration: String {
        let minutes = Int(estimatedDuration / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) hr"
            } else {
                return "\(hours) hr \(remainingMinutes) min"
            }
        }
    }
    
    /// Whether an external app needs to be installed to use this option
    var requiresExternalApp: Bool {
        requiresApp != nil
    }
    
    /// Display name for the transport option
    var displayName: String {
        mode.displayName
    }
    
    /// Icon identifier for UI display
    var iconName: String {
        mode.iconName
    }
    
    // MARK: - Initialization
    
    /// Creates a new TransportOption instance.
    /// - Parameters:
    ///   - id: Unique identifier (defaults to new UUID)
    ///   - mode: Transport mode (car, taxi, transit, etc.)
    ///   - estimatedDuration: Travel time in seconds
    ///   - estimatedArrivalTime: Calculated arrival time at airport
    ///   - costEstimate: Optional cost information
    ///   - reliabilityScore: Reliability rating 0.0-1.0
    ///   - isAvailable: Whether option is currently usable
    ///   - unavailabilityReason: Reason if not available
    ///   - deepLink: Primary deep-link URL
    ///   - requiresApp: Bundle ID of required app
    ///   - fallbackDeepLink: Fallback URL (should be Apple Maps)
    ///   - calculatedAt: When calculation occurred (defaults to now)
    ///   - originLocation: Starting coordinates
    ///   - destinationAirport: Target airport
    init(
        id: UUID = UUID(),
        mode: TransportMode,
        estimatedDuration: TimeInterval,
        estimatedArrivalTime: Date,
        costEstimate: CostEstimate? = nil,
        reliabilityScore: Double,
        isAvailable: Bool = true,
        unavailabilityReason: String? = nil,
        deepLink: URL? = nil,
        requiresApp: String? = nil,
        fallbackDeepLink: URL? = nil,
        calculatedAt: Date = Date(),
        originLocation: LocationCoordinate? = nil,
        destinationAirport: Airport
    ) {
        self.id = id
        self.mode = mode
        self.estimatedDuration = estimatedDuration
        self.estimatedArrivalTime = estimatedArrivalTime
        self.costEstimate = costEstimate
        self.reliabilityScore = max(0.0, min(1.0, reliabilityScore)) // Clamp to 0-1
        self.isAvailable = isAvailable
        self.unavailabilityReason = unavailabilityReason
        self.deepLink = deepLink
        self.requiresApp = requiresApp
        self.fallbackDeepLink = fallbackDeepLink
        self.calculatedAt = calculatedAt
        self.originLocation = originLocation
        self.destinationAirport = destinationAirport
    }
}

// MARK: - Transport Mode

/// Available transport modes for airport transit.
enum TransportMode: String, Codable, CaseIterable {
    /// Personal vehicle (own car, rental car, car service)
    case car
    
    /// Taxi or ride-hailing service (Uber, Grab, Lyft, etc.)
    case taxi
    
    /// Public transportation (train, subway, bus, airport express)
    case publicTransit
    
    /// Airport shuttle or hotel shuttle service
    case shuttle
    
    /// Walking (rarely practical for airports, but included for completeness)
    case walking
    
    /// Display name for UI presentation
    var displayName: String {
        switch self {
        case .car:
            return "Car"
        case .taxi:
            return "Taxi / Ride"
        case .publicTransit:
            return "Public Transit"
        case .shuttle:
            return "Shuttle"
        case .walking:
            return "Walking"
        }
    }
    
    /// SF Symbols icon name for UI
    var iconName: String {
        switch self {
        case .car:
            return "car.fill"
        case .taxi:
            return "car.fill" // Could use custom icon for taxi
        case .publicTransit:
            return "train.side.front.car"
        case .shuttle:
            return "bus.fill"
        case .walking:
            return "figure.walk"
        }
    }
    
    /// Whether this mode typically requires payment
    var isTypicallyPaid: Bool {
        switch self {
        case .car:
            return false // Personal car
        case .taxi, .shuttle:
            return true
        case .publicTransit:
            return true // Usually requires ticket
        case .walking:
            return false
        }
    }
    
    /// Whether real-time availability can be checked
    var hasRealTimeAvailability: Bool {
        switch self {
        case .taxi:
            return true // Ride-hailing apps show availability
        case .car, .publicTransit, .shuttle, .walking:
            return false
        }
    }
}

// MARK: - Cost Estimate

/// Represents cost information for a transport option.
enum CostEstimate: Equatable {
    /// Free transport (personal car, walking)
    case free
    
    /// Fixed price (flat-rate shuttle, fixed-fare taxi)
    case fixed(amount: Double, currency: String)
    
    /// Price range (ride-hailing, variable taxi)
    case range(min: Double, max: Double, currency: String)
    
    /// Formatted display string for the cost
    var displayString: String {
        switch self {
        case .free:
            return "Free"
        case .fixed(let amount, let currency):
            return formatCurrency(amount: amount, currency: currency)
        case .range(let min, let max, let currency):
            let minStr = formatCurrency(amount: min, currency: currency)
            let maxStr = formatCurrency(amount: max, currency: currency)
            return "\(minStr) - \(maxStr)"
        }
    }
    
    /// Helper to format currency amounts
    private func formatCurrency(amount: Double, currency: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(amount)"
    }
}

// MARK: - Codable Implementation for CostEstimate

extension CostEstimate: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, amount, min, max, currency
    }
    
    private enum CostType: String, Codable {
        case free, fixed, range
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .free:
            try container.encode(CostType.free, forKey: .type)
        case .fixed(let amount, let currency):
            try container.encode(CostType.fixed, forKey: .type)
            try container.encode(amount, forKey: .amount)
            try container.encode(currency, forKey: .currency)
        case .range(let min, let max, let currency):
            try container.encode(CostType.range, forKey: .type)
            try container.encode(min, forKey: .min)
            try container.encode(max, forKey: .max)
            try container.encode(currency, forKey: .currency)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(CostType.self, forKey: .type)
        
        switch type {
        case .free:
            self = .free
        case .fixed:
            let amount = try container.decode(Double.self, forKey: .amount)
            let currency = try container.decode(String.self, forKey: .currency)
            self = .fixed(amount: amount, currency: currency)
        case .range:
            let min = try container.decode(Double.self, forKey: .min)
            let max = try container.decode(Double.self, forKey: .max)
            let currency = try container.decode(String.self, forKey: .currency)
            self = .range(min: min, max: max, currency: currency)
        }
    }
}

// MARK: - Location Coordinate

/// Codable and Hashable wrapper for CLLocationCoordinate2D
struct LocationCoordinate: Codable, Equatable, Hashable {
    let latitude: Double
    let longitude: Double
    
    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
    
    init(from coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
    
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Deep Link Generation

extension TransportOption {
    
    /// Generates a TransportOption with appropriate deep-links for a given mode.
    /// - Parameters:
    ///   - mode: Transport mode
    ///   - origin: Starting location
    ///   - destination: Target airport
    ///   - duration: Estimated travel time
    ///   - cost: Optional cost estimate
    /// - Returns: Configured TransportOption with deep-links
    static func create(
        mode: TransportMode,
        origin: CLLocationCoordinate2D,
        destination: Airport,
        duration: TimeInterval,
        cost: CostEstimate? = nil,
        reliabilityScore: Double = 0.8
    ) -> TransportOption {
        let arrivalTime = Date().addingTimeInterval(duration)
        let originCoord = LocationCoordinate(from: origin)
        
        let (deepLink, requiresApp, fallback) = generateDeepLinks(
            mode: mode,
            origin: origin,
            destination: destination
        )
        
        return TransportOption(
            mode: mode,
            estimatedDuration: duration,
            estimatedArrivalTime: arrivalTime,
            costEstimate: cost,
            reliabilityScore: reliabilityScore,
            deepLink: deepLink,
            requiresApp: requiresApp,
            fallbackDeepLink: fallback,
            originLocation: originCoord,
            destinationAirport: destination
        )
    }
    
    /// Generates appropriate deep-links for a transport mode
    private static func generateDeepLinks(
        mode: TransportMode,
        origin: CLLocationCoordinate2D,
        destination: Airport
    ) -> (deepLink: URL?, requiresApp: String?, fallback: URL?) {
        
        // Always generate Apple Maps fallback
        let fallback = generateAppleMapsURL(to: destination)
        
        switch mode {
        case .taxi:
            // Try Uber first, then Grab, fallback to Maps
            if let uberURL = generateUberURL(origin: origin, destination: destination) {
                return (uberURL, "com.uber.UberClient", fallback)
            }
            if let grabURL = generateGrabURL() {
                return (grabURL, "com.grabtaxi.GrabTaxiClient", fallback)
            }
            return (fallback, nil, fallback)
            
        case .publicTransit:
            // Apple Maps with transit directions
            let transitURL = generateAppleMapsURL(to: destination, transportType: .transit)
            return (transitURL, nil, fallback)
            
        case .car, .shuttle, .walking:
            // Apple Maps driving directions
            return (fallback, nil, fallback)
        }
    }
    
    /// Generates Apple Maps URL for directions to airport
    private static func generateAppleMapsURL(
        to airport: Airport,
        transportType: TransportType = .driving
    ) -> URL? {
        let coordinate = "\(airport.latitude),\(airport.longitude)"
        var urlString = "http://maps.apple.com/?daddr=\(coordinate)"
        
        switch transportType {
        case .driving:
            urlString += "&dirflg=d"
        case .transit:
            urlString += "&dirflg=r"
        case .walking:
            urlString += "&dirflg=w"
        }
        
        return URL(string: urlString)
    }
    
    /// Generates Uber deep-link URL
    private static func generateUberURL(
        origin: CLLocationCoordinate2D,
        destination: Airport
    ) -> URL? {
        var components = URLComponents(string: "uber://")!
        components.queryItems = [
            URLQueryItem(name: "action", value: "setPickup"),
            URLQueryItem(name: "pickup[latitude]", value: String(origin.latitude)),
            URLQueryItem(name: "pickup[longitude]", value: String(origin.longitude)),
            URLQueryItem(name: "dropoff[latitude]", value: String(destination.latitude)),
            URLQueryItem(name: "dropoff[longitude]", value: String(destination.longitude)),
            URLQueryItem(name: "dropoff[nickname]", value: destination.name)
        ]
        return components.url
    }
    
    /// Generates Grab deep-link URL
    /// Note: Grab URL scheme is limited; may just open the app
    private static func generateGrabURL() -> URL? {
        return URL(string: "grab://")
    }
    
    enum TransportType {
        case driving, transit, walking
    }
}

// MARK: - Transport Option Comparison

extension Array where Element == TransportOption {
    
    /// Sorts transport options by recommended priority:
    /// 1. Available options first
    /// 2. Fastest arrival time
    /// 3. Higher reliability
    var prioritized: [TransportOption] {
        sorted { option1, option2 in
            // Available options take priority
            if option1.isAvailable != option2.isAvailable {
                return option1.isAvailable && !option2.isAvailable
            }
            
            // Faster is better
            if option1.estimatedDuration != option2.estimatedDuration {
                return option1.estimatedDuration < option2.estimatedDuration
            }
            
            // More reliable is better
            return option1.reliabilityScore > option2.reliabilityScore
        }
    }
    
    /// Returns the best available transport option (for Free tier single-option display)
    var bestOption: TransportOption? {
        prioritized.first { $0.isAvailable }
    }
    
    /// Filters to only available options
    var available: [TransportOption] {
        filter { $0.isAvailable }
    }
}
