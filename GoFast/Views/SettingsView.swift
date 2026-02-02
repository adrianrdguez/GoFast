//
//  SettingsView.swift
//  GoFast
//
//  Minimal settings screen for Google Calendar connection management.
//  Shows connection status, last sync, and disconnect option.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var authService = GoogleCalendarAuthService.shared
    @State private var coordinatorStatus: String = ""
    @State private var showDisconnectConfirmation = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Google Calendar Section
                Section("Calendar Connection") {
                    if authService.isSignedIn {
                        // Connected state
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Connected to Google Calendar")
                                    .font(.body)
                                
                                if let lastSync = getLastSyncDate() {
                                    Text("Last sync: \(formatDate(lastSync))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        
                        // Disconnect button
                        Button("Disconnect Account") {
                            showDisconnectConfirmation = true
                        }
                        .foregroundColor(.red)
                    } else {
                        // Not connected state
                        HStack {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .foregroundColor(.orange)
                            
                            Text("Google Calendar not connected")
                                .font(.body)
                            
                            Spacer()
                        }
                        
                        Button("Connect Google Calendar") {
                            connectGoogleCalendar()
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                // Data Source Info
                Section("Data Source") {
                    Text(coordinatorStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .onAppear {
                            updateStatus()
                        }
                }
                
                // About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Disconnect Account?", isPresented: $showDisconnectConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Disconnect", role: .destructive) {
                    disconnectGoogleCalendar()
                }
            } message: {
                Text("This will remove your Google Calendar connection and stop syncing flight data.")
            }
        }
    }
    
    // MARK: - Helpers
    
    private func getLastSyncDate() -> Date? {
        UserDefaults.standard.object(forKey: "com.gofast.google.lastSync") as? Date
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func updateStatus() {
        coordinatorStatus = FlightDetectionCoordinator.shared.statusMessage
    }
    
    private func connectGoogleCalendar() {
        // Trigger OAuth flow
        Task {
            do {
                _ = try await authService.signIn()
                updateStatus()
                // Optionally trigger a flight sync immediately
            } catch {
                print("[Settings] Failed to connect: \(error)")
            }
        }
    }
    
    private func disconnectGoogleCalendar() {
        FlightDetectionCoordinator.shared.disconnectAll()
        updateStatus()
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
