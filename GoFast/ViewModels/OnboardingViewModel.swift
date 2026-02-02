//
//  OnboardingViewModel.swift
//  GoFast
//
//  Manages onboarding state and flow logic.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class OnboardingViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var currentStep: OnboardingStep = .welcome
    @Published var isAnimating = false
    @Published var selectedFlightOption: FlightOption = .none
    @Published var detectedFlights: [Flight] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Services
    
    let permissionsManager = PermissionsManager()
    let flightDetectionCoordinator = FlightDetectionCoordinator.shared
    
    // MARK: - Computed Properties
    
    var progress: Double {
        switch currentStep {
        case .welcome:
            return 0.0
        case .permissions:
            return 0.33
        case .firstFlight:
            return 0.66
        case .complete:
            return 1.0
        }
    }
    
    var canProceed: Bool {
        switch currentStep {
        case .welcome:
            return true
        case .permissions:
            return permissionsManager.hasCalendarAccess || selectedFlightOption == .mock
        case .firstFlight:
            return selectedFlightOption != .none || !detectedFlights.isEmpty
        case .complete:
            return true
        }
    }
    
    // MARK: - Navigation
    
    func nextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch currentStep {
            case .welcome:
                currentStep = .permissions
            case .permissions:
                currentStep = .firstFlight
            case .firstFlight:
                completeOnboarding()
            case .complete:
                break
            }
        }
    }
    
    func previousStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            switch currentStep {
            case .welcome:
                break
            case .permissions:
                currentStep = .welcome
            case .firstFlight:
                currentStep = .permissions
            case .complete:
                break
            }
        }
    }
    
    func completeOnboarding() {
        // Save to UserDefaults that onboarding is complete
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        
        // Save flight to widget if available
        if let flight = detectedFlights.first {
            SharedDataService.shared.saveFlight(flight)
        } else if selectedFlightOption == .mock {
            let mockFlight = MockFlightData.generate()
            SharedDataService.shared.saveFlight(mockFlight)
        }
        
        withAnimation {
            currentStep = .complete
        }
    }
    
    // MARK: - Flight Detection
    
    func scanCalendarForFlights() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let flights = try await flightDetectionCoordinator.fetchFlights()
            self.detectedFlights = flights
            
            if flights.isEmpty {
                errorMessage = "No flights found in your calendar. Try using a demo flight instead."
            }
        } catch {
            errorMessage = "Could not scan calendar: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func selectMockFlight() {
        selectedFlightOption = .mock
        let mockFlight = MockFlightData.generate()
        detectedFlights = [mockFlight]
    }
    
    func selectRealFlight() {
        selectedFlightOption = .real
    }
}

// MARK: - Supporting Types

enum OnboardingStep: CaseIterable {
    case welcome
    case permissions
    case firstFlight
    case complete
    
    var title: String {
        switch self {
        case .welcome:
            return "Welcome"
        case .permissions:
            return "Calendar Access"
        case .firstFlight:
            return "First Flight"
        case .complete:
            return "Ready"
        }
    }
}

enum FlightOption {
    case none
    case real
    case mock
}
