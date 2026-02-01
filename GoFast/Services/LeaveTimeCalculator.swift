//
//  LeaveTimeCalculator.swift
//  GoFast
//
//  Service responsible for calculating the optimal time to leave for the airport
//  based on flight departure time, transport duration, airport procedures, and user buffers.
//

import Foundation
import CoreLocation
import MapKit

/// Errors that can occur during leave time calculation
enum LeaveTimeCalculationError: Error {
    case invalidFlight
    case transportCalculationFailed(String)
    case locationUnavailable
    case airportNotFound
    
    var localizedDescription: String {
        switch self {
        case .invalidFlight:
            return "Invalid flight data provided."
        case .transportCalculationFailed(let reason):
            return "Could not calculate transport time: \(reason)"
        case .locationUnavailable:
            return "Current location is unavailable."
        case .airportNotFound:
            return "Airport information not found."
        }
    }
}

/// Service that calculates the optimal departure time from the user's current location
/// to arrive at the airport with appropriate time before the flight.
///
/// Calculation formula:
/// Leave Time = Flight Departure Time - Airport Procedure Time - Transport Duration - User Buffer
///
/// Example: For a 5:00 PM domestic flight from DMK airport, 45 min transport time:
/// - Airport arrival time: 5:00 PM - 90 min = 3:30 PM
/// - Leave time with 15 min buffer: 3:30 PM - 45 min - 15 min = 2:30 PM
class LeaveTimeCalculator {
    
    // MARK: - Properties
    
    /// Service for calculating transport ETAs
    private let transportService: TransportService
    
    /// Default buffer times based on tier (Free vs Pro)
    private let isProUser: Bool
    
    /// Custom buffer override (Pro users can set custom values)
    private var customBuffers: [TransportMode: TimeInterval]?
    
    // MARK: - Constants
    
    /// Standard buffer times for Free tier (automatic, non-customizable)
    private enum FreeTierBuffer {
        static let domestic: TimeInterval = 15 * 60      // 15 minutes
        static let international: TimeInterval = 30 * 60  // 30 minutes
    }
    
    /// Default buffer times for Pro tier (can be customized)
    private enum ProTierDefaultBuffer {
        static let defaultValue: TimeInterval = 20 * 60   // 20 minutes default
        static let minValue: TimeInterval = 0             // 0 minutes minimum
        static let maxValue: TimeInterval = 60 * 60       // 60 minutes maximum
    }
    
    // MARK: - Initialization
    
    /// Creates a new LeaveTimeCalculator instance.
    /// - Parameters:
    ///   - transportService: Service for calculating transport ETAs
    ///   - isProUser: Whether user has Pro subscription (affects buffer customization)
    ///   - customBuffers: Optional custom buffer times per transport mode (Pro only)
    init(
        transportService: TransportService = TransportService(),
        isProUser: Bool = false,
        customBuffers: [TransportMode: TimeInterval]? = nil
    ) {
        self.transportService = transportService
        self.isProUser = isProUser
        self.customBuffers = customBuffers
    }
    
    // MARK: - Public API
    
    /// Calculates the optimal time to leave for a flight.
    /// - Parameters:
    ///   - flight: The flight to calculate departure for
    ///   - originLocation: User's current location
    ///   - transportMode: Preferred transport mode
    /// - Returns: Calculation result containing leave time and all components
    /// - Throws: LeaveTimeCalculationError if calculation fails
    func calculateLeaveTime(
        for flight: Flight,
        from originLocation: CLLocationCoordinate2D,
        using transportMode: TransportMode = .car
    ) async throws -> LeaveTimeCalculation {
        // Validate flight
        guard flight.departureTime > Date() else {
            throw LeaveTimeCalculationError.invalidFlight
        }
        
        // Calculate airport procedure time (when user should be at airport)
        let airportArrivalTime = flight.recommendedAirportArrivalTime()
        let procedureTime = flight.isInternational
            ? Flight.AirportProcedureTime.internationalStandard
            : Flight.AirportProcedureTime.domesticStandard
        
        // Calculate transport duration using MapKit
        let transportResult = try await transportService.calculateETA(
            from: originLocation,
            to: flight.departureAirport,
            using: transportMode
        )
        
        // Calculate user buffer based on tier
        let bufferTime = calculateBufferTime(
            for: flight,
            transportMode: transportMode
        )
        
        // Calculate final leave time
        let leaveTime = flight.departureTime
            .addingTimeInterval(-procedureTime)
            .addingTimeInterval(-transportResult.duration)
            .addingTimeInterval(-bufferTime)
        
        // Calculate countdown
        let timeUntilLeave = leaveTime.timeIntervalSinceNow
        
        return LeaveTimeCalculation(
            flight: flight,
            leaveTime: leaveTime,
            airportArrivalTime: airportArrivalTime,
            flightDepartureTime: flight.departureTime,
            transportDuration: transportResult.duration,
            airportProcedureTime: procedureTime,
            userBufferTime: bufferTime,
            timeUntilLeave: timeUntilLeave,
            transportMode: transportMode,
            isProCalculation: isProUser
        )
    }
    
    /// Calculates leave times for multiple transport options (Pro feature).
    /// - Parameters:
    ///   - flight: The flight to calculate departure for
    ///   - originLocation: User's current location
    ///   - transportModes: Array of transport modes to compare
    /// - Returns: Array of calculations for each transport mode, sorted by leave time
    /// - Throws: LeaveTimeCalculationError if calculation fails
    func calculateLeaveTimesForMultipleOptions(
        for flight: Flight,
        from originLocation: CLLocationCoordinate2D,
        using transportModes: [TransportMode] = [.taxi, .car, .publicTransit]
    ) async throws -> [LeaveTimeCalculation] {
        // Free tier only gets single option
        guard isProUser else {
            let singleCalculation = try await calculateLeaveTime(
                for: flight,
                from: originLocation,
                using: .car
            )
            return [singleCalculation]
        }
        
        // Pro tier calculates all requested modes
        var calculations: [LeaveTimeCalculation] = []
        
        for mode in transportModes {
            do {
                let calculation = try await calculateLeaveTime(
                    for: flight,
                    from: originLocation,
                    using: mode
                )
                calculations.append(calculation)
            } catch {
                // Continue with other modes if one fails
                continue
            }
        }
        
        // Sort by leave time (earliest first)
        return calculations.sorted { $0.leaveTime < $1.leaveTime }
    }
    
    /// Returns the recommended transport option for a flight.
    /// Considers ETA, cost, and reliability.
    /// - Parameters:
    ///   - flight: The flight
    ///   - originLocation: User's current location
    /// - Returns: Best transport option
    func recommendTransport(
        for flight: Flight,
        from originLocation: CLLocationCoordinate2D
    ) async throws -> TransportOption {
        return try await transportService.recommendTransport(
            from: originLocation,
            to: flight.departureAirport
        )
    }
    
    // MARK: - Private Methods
    
    /// Calculates user buffer time based on tier and flight type.
    /// - Parameters:
    ///   - flight: The flight
    ///   - transportMode: Transport mode being used
    /// - Returns: Buffer time in seconds
    private func calculateBufferTime(
        for flight: Flight,
        transportMode: TransportMode
    ) -> TimeInterval {
        // Pro users with custom buffers
        if isProUser, let customBuffer = customBuffers?[transportMode] {
            return max(
                ProTierDefaultBuffer.minValue,
                min(ProTierDefaultBuffer.maxValue, customBuffer)
            )
        }
        
        // Pro users without custom settings get default
        if isProUser {
            return ProTierDefaultBuffer.defaultValue
        }
        
        // Free tier: automatic based on flight type
        return flight.isInternational
            ? FreeTierBuffer.international
            : FreeTierBuffer.domestic
    }
    
    /// Updates custom buffer times (Pro only).
    /// - Parameter buffers: Dictionary of custom buffer times by transport mode
    func updateCustomBuffers(_ buffers: [TransportMode: TimeInterval]?) {
        guard isProUser else { return }
        self.customBuffers = buffers
    }
}

// MARK: - Calculation Result

/// Result of a leave time calculation containing all timing components.
struct LeaveTimeCalculation: Codable, Equatable {
    /// The flight this calculation is for
    let flight: Flight
    
    /// Calculated time to leave current location
    let leaveTime: Date
    
    /// Recommended time to arrive at airport
    let airportArrivalTime: Date
    
    /// Original flight departure time
    let flightDepartureTime: Date
    
    /// Duration of transport to airport
    let transportDuration: TimeInterval
    
    /// Time needed for airport procedures (check-in, security, etc.)
    let airportProcedureTime: TimeInterval
    
    /// User buffer time (free automatic or Pro customizable)
    let userBufferTime: TimeInterval
    
    /// Time remaining until need to leave
    let timeUntilLeave: TimeInterval
    
    /// Transport mode used for calculation
    let transportMode: TransportMode
    
    /// Whether this was calculated with Pro features
    let isProCalculation: Bool
    
    // MARK: - Computed Properties
    
    /// Human-readable "Leave by" time
    var formattedLeaveTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: leaveTime)
    }
    
    /// Countdown string (e.g., "45 min", "2 hr 15 min")
    var countdownString: String {
        let minutes = Int(timeUntilLeave / 60)
        
        if minutes < 0 {
            return "Depart now!"
        } else if minutes < 60 {
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
    
    /// Whether it's time to leave (within 5 minutes of leave time)
    var isTimeToLeave: Bool {
        timeUntilLeave <= 300 // 5 minutes = 300 seconds
    }
    
    /// Whether user has already missed the optimal leave time
    var isOverdue: Bool {
        timeUntilLeave < 0
    }
    
    /// Total time from leaving home to flight departure
    var totalJourneyTime: TimeInterval {
        transportDuration + airportProcedureTime + userBufferTime
    }
    
    /// Formatted transport duration
    var formattedTransportDuration: String {
        let minutes = Int(transportDuration / 60)
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes == 0
                ? "\(hours) hr"
                : "\(hours) hr \(remainingMinutes) min"
        }
    }
    
    /// Formatted buffer time
    var formattedBufferTime: String {
        let minutes = Int(userBufferTime / 60)
        return "\(minutes) min"
    }
}

// MARK: - Transport Service

/// Service for calculating transport ETAs and managing transport options.
class TransportService {
    
    /// Calculates estimated time of arrival for a specific transport mode.
    /// - Parameters:
    ///   - origin: Starting location
    ///   - destination: Target airport
    ///   - mode: Transport mode
    /// - Returns: Transport calculation with duration and recommended option
    /// - Throws: Error if calculation fails
    func calculateETA(
        from origin: CLLocationCoordinate2D,
        to destination: Airport,
        using mode: TransportMode
    ) async throws -> TransportCalculation {
        // Use MapKit for ETA calculation
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(
            coordinate: CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)
        ))
        
        // Set transport type
        switch mode {
        case .car, .taxi, .shuttle:
            request.transportType = .automobile
        case .publicTransit:
            request.transportType = .transit
        case .walking:
            request.transportType = .walking
        }
        
        request.departureDate = Date()
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            
            guard let route = response.routes.first else {
                throw LeaveTimeCalculationError.transportCalculationFailed("No route found")
            }
            
            return TransportCalculation(
                duration: route.expectedTravelTime,
                distance: route.distance,
                transportMode: mode
            )
            
        } catch {
            // Fallback to estimated duration if MapKit fails
            let estimatedDuration = estimateDuration(
                from: origin,
                to: destination,
                mode: mode
            )
            
            return TransportCalculation(
                duration: estimatedDuration,
                distance: nil,
                transportMode: mode,
                isEstimated: true
            )
        }
    }
    
    /// Recommends the best transport option based on ETA and reliability.
    func recommendTransport(
        from origin: CLLocationCoordinate2D,
        to destination: Airport
    ) async throws -> TransportOption {
        // Calculate for car/taxi (most reliable for airports)
        let calculation = try await calculateETA(
            from: origin,
            to: destination,
            using: .car
        )
        
        return TransportOption.create(
            mode: .car,
            origin: origin,
            destination: destination,
            duration: calculation.duration
        )
    }
    
    /// Estimates duration when MapKit is unavailable.
    /// Uses conservative estimates based on typical airport distances.
    private func estimateDuration(
        from origin: CLLocationCoordinate2D,
        to destination: Airport,
        mode: TransportMode
    ) -> TimeInterval {
        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let destLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        let distance = originLocation.distance(from: destLocation) // in meters
        
        // Conservative speed estimates (meters per second)
        let speed: Double
        switch mode {
        case .car, .taxi:
            speed = 8.0 // ~30 km/h average (urban traffic)
        case .publicTransit:
            speed = 10.0 // ~36 km/h (train/airport express)
        case .shuttle:
            speed = 7.0 // ~25 km/h (with stops)
        case .walking:
            speed = 1.4 // ~5 km/h
        }
        
        // Calculate time and add 20% buffer for estimation uncertainty
        let estimatedTime = distance / speed
        return estimatedTime * 1.2
    }
}

// MARK: - Transport Calculation

/// Result of a transport ETA calculation.
struct TransportCalculation {
    let duration: TimeInterval
    let distance: CLLocationDistance?
    let transportMode: TransportMode
    let isEstimated: Bool
    
    init(
        duration: TimeInterval,
        distance: CLLocationDistance?,
        transportMode: TransportMode,
        isEstimated: Bool = false
    ) {
        self.duration = duration
        self.distance = distance
        self.transportMode = transportMode
        self.isEstimated = isEstimated
    }
}
