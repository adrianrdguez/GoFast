//
//  IllustrationViews.swift
//  GoFast
//
//  Custom SwiftUI vector illustrations for onboarding.
//  Uses shapes, gradients, and SF Symbols - no external assets needed.
//  Supports dark mode automatically through system colors.
//

import SwiftUI

// MARK: - Welcome Illustration

struct WelcomeIllustration: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background cloud shapes
            CloudShape()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 200, height: 120)
                .offset(x: -50, y: 20)
            
            CloudShape()
                .fill(Color.blue.opacity(0.05))
                .frame(width: 150, height: 80)
                .offset(x: 80, y: -30)
            
            // Main plane with animation
            PlaneWithTrail()
                .offset(y: isAnimating ? -10 : 10)
                .animation(
                    Animation.easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
        }
        .frame(width: 280, height: 200)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Calendar Scan Illustration

struct CalendarScanIllustration: View {
    @State private var scanProgress: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Calendar base
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .frame(width: 180, height: 200)
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
            
            // Calendar header
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.red.opacity(0.8))
                    .frame(width: 180, height: 50)
                    .overlay(
                        HStack(spacing: 8) {
                            ForEach(0..<3) { _ in
                                Circle()
                                    .fill(Color.white.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }
                    )
                
                // Calendar grid
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        ForEach(0..<4) { index in
                            CalendarDayView(
                                day: index + 1,
                                hasFlight: index == 2,
                                isScanned: scanProgress > CGFloat(index) * 0.25
                            )
                        }
                    }
                    
                    HStack(spacing: 16) {
                        ForEach(4..<7) { index in
                            CalendarDayView(
                                day: index + 1,
                                hasFlight: false,
                                isScanned: scanProgress > CGFloat(index) * 0.14
                            )
                        }
                    }
                }
                .padding(.top, 20)
            }
            .frame(width: 180, height: 200)
            
            // Scanning line animation
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color.blue.opacity(0.6), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 160, height: 3)
                .offset(y: -30 + (scanProgress * 100))
        }
        .frame(width: 280, height: 240)
        .onAppear {
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                scanProgress = 1.0
            }
        }
    }
}

// MARK: - Flight Detected Illustration

struct FlightDetectedIllustration: View {
    @State private var showCheckmark = false
    @State private var scale: CGFloat = 0.8
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.green.opacity(0.2), Color.green.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 200, height: 200)
            
            // Plane icon
            Image(systemName: "airplane")
                .font(.system(size: 60, weight: .medium))
                .foregroundColor(.green)
                .rotationEffect(.degrees(-45))
                .scaleEffect(scale)
            
            // Success checkmark
            Circle()
                .fill(Color.green)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                )
                .offset(x: 50, y: 50)
                .scaleEffect(showCheckmark ? 1.0 : 0.0)
                .opacity(showCheckmark ? 1.0 : 0.0)
        }
        .frame(width: 280, height: 200)
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                scale = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
                showCheckmark = true
            }
        }
    }
}

// MARK: - Empty State Illustration

struct EmptyStateIllustration: View {
    @State private var isFloating = false
    
    var body: some View {
        ZStack {
            // Soft background shape
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.gray.opacity(0.1))
                .frame(width: 160, height: 160)
            
            // Plane with question mark
            ZStack {
                Image(systemName: "airplane")
                    .font(.system(size: 50))
                    .foregroundColor(.gray.opacity(0.6))
                    .rotationEffect(.degrees(-45))
                
                // Dashed path indicating search
                Circle()
                    .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(isFloating ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 8.0)
                            .repeatForever(autoreverses: false),
                        value: isFloating
                    )
            }
            .offset(y: isFloating ? -5 : 5)
            .animation(
                Animation.easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true),
                value: isFloating
            )
        }
        .frame(width: 280, height: 200)
        .onAppear {
            isFloating = true
        }
    }
}

// MARK: - Helper Views

struct CloudShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        path.addEllipse(in: CGRect(x: 0, y: height * 0.3, width: width * 0.5, height: height * 0.6))
        path.addEllipse(in: CGRect(x: width * 0.25, y: 0, width: width * 0.5, height: height * 0.8))
        path.addEllipse(in: CGRect(x: width * 0.5, y: height * 0.2, width: width * 0.5, height: height * 0.6))
        
        return path
    }
}

struct PlaneWithTrail: View {
    var body: some View {
        ZStack {
            // Contrail
            Path { path in
                path.move(to: CGPoint(x: 0, y: 20))
                path.addCurve(
                    to: CGPoint(x: -80, y: 30),
                    control1: CGPoint(x: -20, y: 20),
                    control2: CGPoint(x: -50, y: 40)
                )
            }
            .stroke(
                LinearGradient(
                    colors: [Color.blue.opacity(0.4), Color.blue.opacity(0.0)],
                    startPoint: .trailing,
                    endPoint: .leading
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .frame(width: 100, height: 60)
            .offset(x: -20)
            
            // Plane
            Image(systemName: "airplane.fill")
                .font(.system(size: 50, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .rotationEffect(.degrees(-45))
                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
        }
    }
}

struct CalendarDayView: View {
    let day: Int
    let hasFlight: Bool
    let isScanned: Bool
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(hasFlight && isScanned ? Color.blue.opacity(0.2) : Color.clear)
                .frame(width: 28, height: 28)
            
            if hasFlight && isScanned {
                Image(systemName: "airplane")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.blue)
            } else {
                Text("\(day)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        .opacity(isScanned ? 1.0 : 0.3)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        WelcomeIllustration()
            .frame(height: 200)
        
        CalendarScanIllustration()
            .frame(height: 240)
        
        FlightDetectedIllustration()
            .frame(height: 200)
        
        EmptyStateIllustration()
            .frame(height: 200)
    }
    .padding()
}
