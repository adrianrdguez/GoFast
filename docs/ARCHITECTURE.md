# Architecture

## Overview

GoFast uses a lightweight, pragmatic MVVM architecture optimized for a widget-first experience. The architecture prioritizes simplicity, testability, and clear separation of concerns.

## Architecture Pattern: MVVM

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│    View     │────▶│  ViewModel  │────▶│    Model    │
│   (SwiftUI) │◀────│  (Observable│◀────│  (Structs)  │
└─────────────┘     │   Objects)  │     └─────────────┘
                    └─────────────┘            │
                          │                    │
                          ▼                    ▼
                    ┌─────────────┐     ┌─────────────┐
                    │   Widget    │     │  Services   │
                    │  Extension  │     │  (Business  │
                    │             │     │   Logic)    │
                    └─────────────┘     └─────────────┘
```

## Layer Responsibilities

### Models
**Location**: `GoFast/Models/`

Pure data structures representing domain concepts:
- `Flight`: Flight details, detection source, status
- `Airport`: IATA code, location, timezone, procedures
- `TransportOption`: Transport mode, ETA, cost, deep-link
- Immutable structs with value semantics
- Codable for persistence via App Groups

### Views
**Location**: `GoFast/Views/`

SwiftUI views for app interface:
- `ContentView`: Root container
- `OnboardingView`: First-time setup
- `SettingsView`: Configuration screens
- `FlightListView`: Detected flights display
- No business logic—pure presentation

### ViewModels
**Location**: `GoFast/ViewModels/`

Observable objects connecting views to services:
- `FlightListViewModel`: Manages flight detection and list state
- `SettingsViewModel`: Handles user preferences and Pro features
- `OnboardingViewModel`: Coordinates permissions and setup
- Publishers for async operations (Combine)
- Single source of truth for view state

### Services
**Location**: `GoFast/Services/`

Business logic and external integrations:
- `FlightDetectionService`: Scans calendar for flights using 3-tier detection
- `LeaveTimeCalculator`: Computes optimal departure time
- `CalendarService`: EventKit wrapper with permissions
- `TransportService`: ETA calculation and deep-link generation
- `UserDefaultsService`: App Groups persistence
- Protocol-based for testability

### Widgets
**Location**: `GoFast/Widgets/`

Widget extension and configuration:
- `FlightWidget`: WidgetBundle with small/medium/large variants
- `FlightProvider`: TimelineProvider implementation
- `FlightEntry`: TimelineEntry with flight data
- `FlightWidgetView`: SwiftUI views for each widget size
- Reads from App Groups, never directly from calendar

### Utils
**Location**: `GoFast/Utils/`

Reusable utilities:
- `Constants.swift`: App-wide constants (buffers, timeouts)
- `Extensions.swift`: Swift/Foundation extensions
- `Logger.swift`: Unified logging
- `DateUtils.swift`: Date formatting and calculations

## Data Flow: App ↔ Widget

### App Groups Strategy

Both app and widget share data via App Groups (`group.com.gofast.shared`):

```
App Side:
┌─────────────────┐
│ FlightDetection │──┐
│     Service     │  │
└─────────────────┘  │    ┌─────────────────┐
                     ├───▶│  App Groups     │
┌─────────────────┐  │    │  UserDefaults   │
│ LeaveTimeCalc   │──┘    │  & File Storage │
└─────────────────┘       └────────┬────────┘
                                   │
Widget Side:                       ▼
                          ┌─────────────────┐
                          │  FlightWidget   │
                          │  (reads only)   │
                          └─────────────────┘
```

### Data Flow Rules

1. **App writes, widget reads**: Widget never modifies shared data
2. **Background updates**: App updates data via background tasks
3. **Widget reload**: App triggers widget reload after data changes
4. **Fallback data**: Widget displays cached data if no fresh data available
5. **Timeline-driven**: Widget uses TimelineProvider for automatic refresh

## Communication Patterns

### App → Widget
- Save data to App Groups UserDefaults
- Call `WidgetCenter.shared.reloadTimelines(ofKind:)`
- Widget automatically refreshes on next timeline update

### Widget → App
- Deep-links using URL scheme (`gofast://settings`, `gofast://flight/123`)
- App handles URLs in `onOpenURL` modifier
- Navigation based on URL parameters

## Design Principles

### 1. Single Responsibility
Each component has one clear purpose. ViewModels don't calculate ETAs; Services don't manage view state.

### 2. Dependency Injection
Services injected into ViewModels via protocols. Enables testing with mocks.

### 3. Reactive Updates
Combine publishers for async operations. Views react to ViewModel state changes automatically.

### 4. Fail Gracefully
Every service has fallback behavior. Calendar access denied? Show onboarding. No flights detected? Show empty state with instructions.

### 5. Widget Performance
Widget views are lightweight. Complex calculations happen in app, results cached for widget.

## Error Handling Strategy

- **Service Layer**: Returns Result<T, Error> or throws
- **ViewModel Layer**: Catches errors, updates published error state
- **View Layer**: Displays error UI based on ViewModel state
- **Widget Layer**: Shows placeholder or last-known-good data

## Testing Strategy

- **Unit Tests**: Services and ViewModels with mocked dependencies
- **Integration Tests**: End-to-end flight detection flow
- **UI Tests**: Critical paths (onboarding, widget visibility)
- **Widget Tests**: Timeline generation and snapshot testing

## Platform Considerations

- **iOS 16+**: Target for widget features
- **iOS 17+**: Interactive widgets (post-MVP)
- **App Groups**: Required for widget data sharing
- **Background Refresh**: Used to update flight detection periodically
