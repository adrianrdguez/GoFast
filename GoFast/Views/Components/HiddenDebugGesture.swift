//
//  HiddenDebugGesture.swift
//  GoFast
//

import SwiftUI

struct HiddenDebugAccess: ViewModifier {
    @State private var tapCount = 0
    @State private var showDebug = false
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                tapCount += 1
                if tapCount >= 5 {
                    action()
                    tapCount = 0
                }
                
                // Reset after 2 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    tapCount = 0
                }
            }
    }
}

extension View {
    func hiddenDebugAccess(action: @escaping () -> Void) -> some View {
        modifier(HiddenDebugAccess(action: action))
    }
}

// MARK: - Debug Screen Wrapper

struct DebugScreenContainer<Content: View>: View {
    let content: Content
    @State private var showDebug = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            content
            
            #if DEBUG
            // Always available in debug builds
            EmptyView()
            #else
            // Hidden gesture in release builds
            Color.clear
                .hiddenDebugAccess {
                    showDebug = true
                }
            #endif
        }
        .sheet(isPresented: $showDebug) {
            DebugScreen()
        }
    }
}

// MARK: - Debug Screen (Existing ContentView becomes this)

struct DebugScreen: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            // Reuse existing ContentView as debug screen
            ContentView()
                .navigationTitle("Debug")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}
