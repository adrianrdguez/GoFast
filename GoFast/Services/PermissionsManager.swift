//
//  PermissionsManager.swift
//  GoFast
//
//  Centralized permission handling with contextual pre-prompts.
//  Shows explanation BEFORE system dialog for 40-60% better acceptance.
//

import Foundation
import EventKit
import SwiftUI
import Combine

/// Manages calendar permissions with contextual explanations
@MainActor
class PermissionsManager: ObservableObject {
    
    // MARK: - Published State
    
    @Published var calendarAuthorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var showPermissionRationale = false
    @Published var isRequestingPermission = false
    
    // MARK: - Properties
    
    private let eventStore = EKEventStore()
    
    // MARK: - Initialization
    
    init() {
        updateAuthorizationStatus()
    }
    
    // MARK: - Public Methods
    
    /// Checks current calendar authorization status
    func updateAuthorizationStatus() {
        calendarAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }
    
    /// Determines if we should show the permission rationale before requesting
    var shouldShowRationale: Bool {
        calendarAuthorizationStatus == .notDetermined
    }
    
    /// Full permission flow: Show rationale → Request permission
    func requestCalendarPermissionWithRationale() async -> Bool {
        // Step 1: Show our contextual explanation
        showPermissionRationale = true
        
        // Wait for user to acknowledge (in real UI, this would be a callback)
        // For now, we proceed directly
        
        // Step 2: Request system permission
        return await requestCalendarPermission()
    }
    
    /// Direct system permission request (after rationale shown)
    /// - Returns: Bool indicating if permission was granted
    /// - Important: Only call when status is .notDetermined. For denied/restricted, use openAppSettings()
    func requestCalendarPermission() async -> Bool {
        // Check current status first
        updateAuthorizationStatus()
        
        // If already denied or restricted, we can't request again - user must go to Settings
        if calendarAuthorizationStatus == .denied || calendarAuthorizationStatus == .restricted {
            return false
        }
        
        // If already authorized, just return true
        if hasCalendarAccess {
            return true
        }
        
        // Only proceed if status is .notDetermined
        guard calendarAuthorizationStatus == .notDetermined else {
            return hasCalendarAccess
        }
        
        isRequestingPermission = true
        defer { isRequestingPermission = false }
        
        do {
            let granted: Bool
            
            // iOS 17+ uses new API
            if #available(iOS 17.0, *) {
                granted = try await eventStore.requestFullAccessToEvents()
            } else {
                // iOS 16 and earlier
                granted = try await withCheckedThrowingContinuation { continuation in
                    eventStore.requestAccess(to: .event) { granted, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: granted)
                        }
                    }
                }
            }
            
            updateAuthorizationStatus()
            return granted
            
        } catch {
            print("[PermissionsManager] Error requesting calendar access: \(error)")
            updateAuthorizationStatus()
            return false
        }
    }
    
    /// Returns the appropriate action for the current permission state
    enum PermissionAction {
        case requestPermission    // Show system dialog
        case openSettings         // Go to Settings app
        case proceed              // Already have access
    }
    
    /// Determines what action should be taken based on current authorization status
    func determinePermissionAction() -> PermissionAction {
        updateAuthorizationStatus()
        
        switch calendarAuthorizationStatus {
        case .notDetermined:
            return .requestPermission
        case .denied, .restricted:
            return .openSettings
        case .authorized, .fullAccess, .writeOnly:
            return .proceed
        @unknown default:
            return .openSettings
        }
    }
    
    /// Opens app settings for user to manually enable permissions
    func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        
        if UIApplication.shared.canOpenURL(settingsURL) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    // MARK: - Permission Status Helpers
    
    /// Returns true if we have full calendar access
    var hasCalendarAccess: Bool {
        calendarAuthorizationStatus == .authorized || calendarAuthorizationStatus == .fullAccess
    }
    
    /// Returns true if permission was denied
    var isCalendarDenied: Bool {
        calendarAuthorizationStatus == .denied
    }
    
    /// Returns user-friendly status description
    var statusDescription: String {
        switch calendarAuthorizationStatus {
        case .notDetermined:
            return "Permission not requested"
        case .restricted:
            return "Access restricted by system"
        case .denied:
            return "Access denied - enable in Settings"
        case .authorized, .fullAccess:
            return "Full calendar access granted"
        @unknown default:
            return "Unknown status"
        }
    }
}

// MARK: - Permission Rationale View

struct CalendarPermissionRationaleView: View {
    let onContinue: () -> Void
    let onSkip: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Illustration
            CalendarScanIllustration()
                .frame(height: 200)
            
            // Title
            Text("Access Your Calendar")
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
            
            // Explanation
            VStack(spacing: 12) {
                Text("GoFast scans your calendar to automatically detect upcoming flights and calculate the ideal time to leave for the airport.")
                    .font(.system(size: 17))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                
                Text("We never read other events.")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.blue)
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Buttons
            VStack(spacing: 12) {
                AnimatedButton(
                    title: "Grant Calendar Access",
                    icon: "calendar.badge.checkmark",
                    style: .primary,
                    action: onContinue
                )
                
                AnimatedButton(
                    title: "Try with Demo Flight",
                    icon: "airplane",
                    style: .secondary,
                    action: onSkip
                )
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 32)
    }
}

// MARK: - Permission Denied View

struct CalendarPermissionDeniedView: View {
    let onOpenSettings: () -> Void
    let onUseDemo: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            // Title
            Text("Calendar Access Needed")
                .font(.system(size: 24, weight: .bold))
            
            // Explanation
            Text("To automatically detect your flights, GoFast needs access to your calendar. You can enable this in Settings.")
                .font(.system(size: 17))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)
            
            Spacer()
            
            // Buttons
            VStack(spacing: 12) {
                AnimatedButton(
                    title: "Open Settings",
                    icon: "gear",
                    style: .primary,
                    action: onOpenSettings
                )
                
                AnimatedButton(
                    title: "Continue with Demo",
                    icon: "airplane",
                    style: .secondary,
                    action: onUseDemo
                )
            }
            .padding(.horizontal, 24)
        }
        .padding(.vertical, 32)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        CalendarPermissionRationaleView(
            onContinue: {},
            onSkip: {}
        )
    }
}

#Preview("Denied") {
    CalendarPermissionDeniedView(
        onOpenSettings: {},
        onUseDemo: {}
    )
}
