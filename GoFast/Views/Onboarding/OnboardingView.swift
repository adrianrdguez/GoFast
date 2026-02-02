//
//  OnboardingView.swift
//  GoFast
//
//  Main onboarding container with page transitions.
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()
    @State private var hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    
    var body: some View {
        Group {
            if hasCompletedOnboarding {
                MainAppView()
            } else {
                onboardingFlow
            }
        }
    }
    
    private var onboardingFlow: some View {
        VStack(spacing: 0) {
            // Progress indicator
            if viewModel.currentStep != .complete {
                ProgressView(value: viewModel.progress)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
            }
            
            // Step content with transitions
            ZStack {
                switch viewModel.currentStep {
                case .welcome:
                    OnboardingStep1Welcome(viewModel: viewModel)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                
                case .permissions:
                    OnboardingStep2Permissions(viewModel: viewModel)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                
                case .firstFlight:
                    OnboardingStep3FirstFlight(viewModel: viewModel)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                
                case .complete:
                    CompletionView {
                        withAnimation {
                            hasCompletedOnboarding = true
                        }
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
        }
    }
}

// MARK: - Completion View

struct CompletionView: View {
    let onComplete: () -> Void
    @State private var showCheckmark = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Success animation
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "checkmark")
                    .font(.system(size: 50, weight: .bold))
                    .foregroundColor(.green)
                    .scaleEffect(showCheckmark ? 1.0 : 0.0)
            }
            
            VStack(spacing: 12) {
                Text("You're All Set!")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Add the GoFast widget to your home screen to see when to leave for your flight.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            Button("Get Started") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.5).delay(0.2)) {
                showCheckmark = true
            }
        }
    }
}

// MARK: - Main App View

struct MainAppView: View {
    @State private var showDebug = false
    @State private var currentFlight: Flight?
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Current flight section
                Text("Current Flight")
                    .font(.title)
                    .fontWeight(.bold)
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                } else if let flight = currentFlight {
                    MainAppFlightCard(flight: flight)
                } else {
                    EmptyFlightState()
                }
                
                Spacer()
                
                // Debug access (5 taps on version)
                Text("GoFast v1.0")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.5))
                    .onTapGesture(count: 5) {
                        showDebug = true
                    }
            }
            .padding()
            .navigationTitle("GoFast")
        }
        .sheet(isPresented: $showDebug) {
            DebugScreen()
        }
        .onAppear {
            loadFlight()
        }
        .onChange(of: showDebug) { newValue in
            if !newValue {
                // Reload when debug screen closes
                loadFlight()
            }
        }
    }
    
    private func loadFlight() {
        isLoading = true
        currentFlight = SharedDataService.shared.loadFlight()
        isLoading = false
    }
}

// MARK: - Flight Card

struct MainAppFlightCard: View {
    let flight: Flight
    
    private var urgencyColor: Color {
        let timeUntil = flight.timeUntilDeparture
        if timeUntil < 30 * 60 {
            return .red
        } else if timeUntil < 90 * 60 {
            return .orange
        } else {
            return .green
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with flight number and urgency indicator
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let flightNumber = flight.flightNumber {
                        Text(flightNumber)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    Text("\(flight.departureAirport.id) → \(flight.arrivalAirport?.id ?? "?")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Urgency indicator
                Circle()
                    .fill(urgencyColor)
                    .frame(width: 12, height: 12)
            }
            
            Divider()
            
            // Departure info
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text(formatDate(flight.departureTime))
                } icon: {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                }
                
                Label {
                    Text(formatTime(flight.departureTime))
                } icon: {
                    Image(systemName: "clock")
                        .foregroundColor(.blue)
                }
                
                if let terminal = flight.terminal {
                    Label {
                        Text(terminal)
                    } icon: {
                        Image(systemName: "building.2")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
                
                if let gate = flight.gate {
                    Label {
                        Text(gate)
                    } icon: {
                        Image(systemName: "door.left.hand.open")
                            .foregroundColor(.secondary)
                    }
                    .font(.caption)
                }
            }
            
            Divider()
            
            // Countdown
            HStack {
                Image(systemName: "hourglass")
                    .foregroundColor(urgencyColor)
                
                Text(formatTimeInterval(flight.timeUntilDeparture))
                    .font(.headline)
                    .foregroundColor(urgencyColor)
                
                Spacer()
                
                Text("until departure")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else if interval > 0 {
            return "< 1m"
        } else {
            return "Departed"
        }
    }
}

// MARK: - Empty State

struct EmptyFlightState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "airplane")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No Upcoming Flights")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Add a flight to your calendar or use the debug screen to add a test flight.")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(16)
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
