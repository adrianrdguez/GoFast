//
//  OnboardingStep2Permissions.swift
//  GoFast
//

import SwiftUI

struct OnboardingStep2Permissions: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var showDeniedState = false
    @State private var shouldOpenSettings = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Illustration
            CalendarScanIllustration()
                .frame(height: 200)
            
            Text(showDeniedState ? "Calendar Access Needed" : "Access Your Calendar")
                .font(.title)
                .fontWeight(.bold)
            
            Text(showDeniedState 
                 ? "To automatically detect your flights, GoFast needs access to your calendar. Please enable it in Settings."
                 : "GoFast scans your calendar to automatically detect upcoming flights and calculate the ideal time to leave for the airport.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if !showDeniedState {
                Text("We never read other events.")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            // State-based UI
            if showDeniedState {
                // Permission denied UI - Settings button
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
                    Button(shouldOpenSettings ? "Open Settings" : "Grant Calendar Access") {
                        Task {
                            await handlePermissionAction()
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
            checkInitialPermissionState()
        }
    }
    
    /// Check permission status when view appears and set appropriate UI state
    private func checkInitialPermissionState() {
        let action = viewModel.permissionsManager.determinePermissionAction()
        
        switch action {
        case .requestPermission:
            // Normal flow - show request button
            showDeniedState = false
            shouldOpenSettings = false
            
        case .openSettings:
            // Already denied or restricted - show denied UI immediately
            showDeniedState = true
            shouldOpenSettings = true
            
        case .proceed:
            // Already have access - proceed to next step
            Task {
                await viewModel.scanCalendarForFlights()
                viewModel.nextStep()
            }
        }
    }
    
    /// Handle the permission button tap based on current authorization status
    private func handlePermissionAction() async {
        let action = viewModel.permissionsManager.determinePermissionAction()
        
        switch action {
        case .requestPermission:
            // First time request - show system dialog
            let granted = await viewModel.permissionsManager.requestCalendarPermission()
            if granted {
                await viewModel.scanCalendarForFlights()
                viewModel.nextStep()
            } else {
                // User denied in system dialog - show denied state
                withAnimation {
                    showDeniedState = true
                }
            }
            
        case .openSettings:
            // Already denied - open Settings app
            viewModel.permissionsManager.openAppSettings()
            
        case .proceed:
            // Already authorized - proceed
            await viewModel.scanCalendarForFlights()
            viewModel.nextStep()
        }
    }
}
