//
//  OnboardingStep2Permissions.swift
//  GoFast
//

import SwiftUI

struct OnboardingStep2Permissions: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var showDeniedState = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Illustration
            CalendarScanIllustration()
                .frame(height: 200)
            
            Text("Access Your Calendar")
                .font(.title)
                .fontWeight(.bold)
            
            Text("GoFast scans your calendar to automatically detect upcoming flights and calculate the ideal time to leave for the airport.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("We never read other events.")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.blue)
            
            Spacer()
            
            // State-based UI
            if showDeniedState {
                // Permission denied UI
                VStack(spacing: 12) {
                    Button("Open Settings") {
                        viewModel.permissionsManager.openAppSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Continue with Demo Flight") {
                        viewModel.selectMockFlight()
                        viewModel.nextStep()
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                // Normal permission request UI
                VStack(spacing: 12) {
                    Button("Grant Calendar Access") {
                        Task {
                            let granted = await viewModel.permissionsManager.requestCalendarPermission()
                            if granted {
                                await viewModel.scanCalendarForFlights()
                                viewModel.nextStep()
                            } else {
                                showDeniedState = true
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button("Try with Demo Flight") {
                        viewModel.selectMockFlight()
                        viewModel.nextStep()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding()
        .onAppear {
            viewModel.permissionsManager.updateAuthorizationStatus()
            if viewModel.permissionsManager.isCalendarDenied {
                showDeniedState = true
            }
        }
    }
}
