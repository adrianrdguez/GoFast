//
//  OnboardingStep3FirstFlight.swift
//  GoFast
//

import SwiftUI

struct OnboardingStep3FirstFlight: View {
    @ObservedObject var viewModel: OnboardingViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            // Success illustration if we have a flight
            if !viewModel.detectedFlights.isEmpty {
                FlightDetectedIllustration()
                    .frame(height: 180)
                
                Text("Flight Found!")
                    .font(.title)
                    .fontWeight(.bold)
                
                if let flight = viewModel.detectedFlights.first {
                    FlightCard(flight: flight)
                }
            } else if viewModel.isLoading {
                ProgressView("Scanning calendar...")
                    .scaleEffect(1.5)
                    .frame(height: 200)
            } else {
                // No flights yet - show options
                EmptyStateIllustration()
                    .frame(height: 180)
                
                Text("Let's Find Your Flight")
                    .font(.title)
                    .fontWeight(.bold)
            }
            
            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.orange)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Action buttons
            if !viewModel.detectedFlights.isEmpty {
                // We have a flight - proceed
                Button("Continue") {
                    viewModel.completeOnboarding()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else if !viewModel.isLoading {
                // No flight - show options
                VStack(spacing: 12) {
                    Button("Scan My Calendar") {
                        Task {
                            await viewModel.scanCalendarForFlights()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Try Demo Flight") {
                        viewModel.selectMockFlight()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
    }
}

// MARK: - Flight Card

struct FlightCard: View {
    let flight: Flight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(flight.flightNumber ?? "Flight")
                    .font(.headline)
                Spacer()
                Text(flight.departureAirport.id)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("Departs: \(flight.departureTime, style: .date)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}
