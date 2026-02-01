//
//  OnboardingStep1Welcome.swift
//  GoFast
//
//  Welcome screen with animated illustration and clear value proposition.
//

import SwiftUI

struct OnboardingStep1Welcome: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Illustration with animation
            WelcomeIllustration()
                .frame(height: 220)
                .padding(.top, 40)
                .scaleEffect(isAnimating ? 1.0 : 0.8)
                .opacity(isAnimating ? 1.0 : 0.0)
            
            Spacer()
            
            // Content
            VStack(spacing: 20) {
                // Title
                Text("Never Miss a Flight")
                    .font(.system(size: 32, weight: .bold))
                    .multilineTextAlignment(.center)
                    .slideInTransition(isActive: isAnimating)
                
                // Description
                Text("GoFast scans your calendar and tells you exactly when to leave for the airport.")
                    .font(.system(size: 17))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
                    .fadeInAnimation(isVisible: isAnimating, delay: 0.2)
                
                // Features
                HStack(spacing: 24) {
                    FeatureItem(icon: "calendar.badge.checkmark", text: "Auto-detect flights")
                    FeatureItem(icon: "hourglass", text: "Countdown timer")
                    FeatureItem(icon: "bell.fill", text: "Smart alerts")
                }
                .padding(.top, 16)
                .fadeInAnimation(isVisible: isAnimating, delay: 0.4)
            }
            
            Spacer()
            
            // CTA Button
            VStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.nextStep()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Text("Get Started")
                            .font(.system(size: 17, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
                .fadeInAnimation(isVisible: isAnimating, delay: 0.6)
                
                // Version number with hidden debug access
                Text("Version 1.0")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.5))
                    .onTapGesture(count: 5) {
                        // Hidden debug gesture
                        NotificationCenter.default.post(name: .init("ShowDebugScreen"), object: nil)
                    }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Feature Item

struct FeatureItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 80)
    }
}

// MARK: - Preview

#Preview {
    OnboardingStep1Welcome(viewModel: OnboardingViewModel())
}
