//
//  AnimationExtensions.swift
//  GoFast
//
//  SwiftUI animation utilities for micro-interactions and transitions.
//  Used throughout onboarding and main app.
//

import SwiftUI

// MARK: - Animation Constants

struct AnimationConstants {
    // Durations
    static let micro: Double = 0.1      // Button presses
    static let quick: Double = 0.2      // Small state changes
    static let standard: Double = 0.3   // Page transitions
    static let slow: Double = 0.5       // Hero animations
    
    // Curves
    static let standardCurve: Animation = .easeInOut(duration: standard)
    static let springCurve: Animation = .spring(response: 0.3, dampingFraction: 0.7)
    static let bouncyCurve: Animation = .spring(response: 0.4, dampingFraction: 0.5)
}

// MARK: - View Extensions

extension View {
    // Button press animation
    func buttonPressAnimation(isPressed: Bool) -> some View {
        self
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeOut(duration: AnimationConstants.micro), value: isPressed)
    }
    
    // Page transition - slide in from right
    func slideInTransition(isActive: Bool) -> some View {
        self
            .offset(x: isActive ? 0 : 50)
            .opacity(isActive ? 1 : 0)
            .animation(AnimationConstants.standardCurve, value: isActive)
    }
    
    // Fade in animation
    func fadeInAnimation(isVisible: Bool, delay: Double = 0) -> some View {
        self
            .opacity(isVisible ? 1 : 0)
            .animation(
                .easeIn(duration: AnimationConstants.standard)
                    .delay(delay),
                value: isVisible
            )
    }
    
    // Scale pop animation (for success states)
    func scalePopAnimation(isActive: Bool) -> some View {
        self
            .scaleEffect(isActive ? 1.0 : 0.8)
            .opacity(isActive ? 1.0 : 0.0)
            .animation(AnimationConstants.bouncyCurve, value: isActive)
    }
    
    // Shimmer loading effect
    func shimmer(isLoading: Bool) -> some View {
        self
            .overlay(
                GeometryReader { geometry in
                    if isLoading {
                        ShimmerView()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
            )
    }
}

// MARK: - Shimmer View

struct ShimmerView: View {
    @State private var phase: CGFloat = 0
    
    var body: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.1),
                Color.white.opacity(0.3),
                Color.white.opacity(0.1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .mask(
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .white, .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .offset(x: phase * 200 - 100)
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 1.0
            }
        }
    }
}

// MARK: - Animated Button

struct AnimatedButton: View {
    let title: String
    let icon: String?
    let style: ButtonStyle
    let action: () -> Void
    
    @State private var isPressed = false
    
    enum ButtonStyle {
        case primary
        case secondary
        case ghost
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(12)
            .shadow(color: shadowColor, radius: isPressed ? 2 : 8, x: 0, y: isPressed ? 1 : 4)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.easeOut(duration: 0.1), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
    
    private var backgroundColor: Color {
        switch style {
        case .primary:
            return Color.blue
        case .secondary:
            return Color(UIColor.systemGray6)
        case .ghost:
            return Color.clear
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return .primary
        case .ghost:
            return .blue
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .primary:
            return .blue.opacity(0.3)
        default:
            return .clear
        }
    }
}

// MARK: - Progress Indicator

struct AnimatedProgressBar: View {
    let progress: Double // 0.0 to 1.0
    let totalSteps: Int
    let currentStep: Int
    
    var body: some View {
        VStack(spacing: 8) {
            // Progress dots
            HStack(spacing: 8) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    Circle()
                        .fill(index <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == currentStep ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3), value: currentStep)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    
                    // Fill
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.blue)
                        .frame(width: geometry.size.width * progress, height: 4)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Card Selection Animation

struct SelectableCard<Content: View>: View {
    let isSelected: Bool
    let action: () -> Void
    let content: Content
    
    init(isSelected: Bool, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        Button(action: action) {
            content
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white)
                        .shadow(
                            color: isSelected ? Color.blue.opacity(0.3) : Color.black.opacity(0.05),
                            radius: isSelected ? 12 : 4,
                            x: 0,
                            y: isSelected ? 4 : 2
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Success Checkmark

struct AnimatedCheckmark: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.green)
                .frame(width: 60, height: 60)
            
            Path { path in
                path.move(to: CGPoint(x: 20, y: 30))
                path.addLine(to: CGPoint(x: 27, y: 37))
                path.addLine(to: CGPoint(x: 40, y: 23))
            }
            .trim(from: 0, to: animate ? 1 : 0)
            .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .frame(width: 60, height: 60)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                animate = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 30) {
        AnimatedButton(
            title: "Get Started",
            icon: "arrow.right",
            style: .primary,
            action: {}
        )
        
        AnimatedButton(
            title: "Maybe Later",
            icon: nil,
            style: .secondary,
            action: {}
        )
        
        AnimatedProgressBar(progress: 0.5, totalSteps: 3, currentStep: 1)
            .padding(.horizontal)
        
        HStack(spacing: 16) {
            SelectableCard(isSelected: true, action: {}) {
                VStack(alignment: .leading) {
                    Image(systemName: "airplane")
                        .font(.title2)
                    Text("Scan Calendar")
                        .font(.headline)
                }
            }
            
            SelectableCard(isSelected: false, action: {}) {
                VStack(alignment: .leading) {
                    Image(systemName: "person.fill")
                        .font(.title2)
                    Text("Demo Flight")
                        .font(.headline)
                }
            }
        }
        .padding(.horizontal)
        
        AnimatedCheckmark()
    }
    .padding()
}
