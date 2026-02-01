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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Current flight section
                Text("Current Flight")
                    .font(.title)
                    .fontWeight(.bold)
                
                // Placeholder for main app UI
                Text("Your flights will appear here")
                    .foregroundColor(.secondary)
                
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
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
