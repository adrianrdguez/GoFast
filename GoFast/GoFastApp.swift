//
//  GoFastApp.swift
//  GoFast
//

import SwiftUI

@main
struct GoFastApp: App {
    var body: some Scene {
        WindowGroup {
            OnboardingView()
                .onOpenURL { url in
                    // Handle OAuth callback URLs
                    if url.scheme == "com.gofast" {
                        GoogleCalendarAuthService.shared.handleRedirect(url)
                    }
                }
        }
    }
}
