//
//  WidgetContainer.swift
//  GoFastWidget
//
//  Reusable widget container that handles iOS 17+ containerBackground API
//  and automatically adapts to light/dark theme.
//

import SwiftUI
import WidgetKit

/// Container view for widgets that properly handles background on iOS 17+
struct WidgetContainer<Content: View>: View {
    let content: Content
    let alignment: Alignment
    
    init(
        alignment: Alignment = .topLeading,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.alignment = alignment
    }
    
    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .applyWidgetBackground()
    }
}

// MARK: - Widget Background Modifier

extension View {
    /// Applies the correct background modifier for widgets based on iOS version
    /// Uses containerBackground on iOS 17+, falls back to background on older versions
    @ViewBuilder
    func applyWidgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) {
                Color(UIColor.systemBackground)
            }
        } else {
            background(Color(UIColor.systemBackground))
        }
    }
}

// MARK: - Empty State Container

/// Specialized container for empty state widgets
struct EmptyStateWidgetContainer<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .applyWidgetBackground()
    }
}
